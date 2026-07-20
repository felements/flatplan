# Release Pipeline Design

**Date:** 2026-07-20
**Status:** Draft for review

## Goal

Every merge to `main` automatically: computes the next semantic version from git
history, runs tests, builds all distributables, generates user-facing release
notes, publishes a GitHub Release with a `v<version>` tag, and — behind a manual
approval gate — submits the Windows build to the Microsoft Store.

Modeled on the GitLab CI pipeline in `tws.game.poc` (svu versioning, AI release
notes with fallback, release job tags the repo as the baseline for the next run).

## Current state and what is broken

- `.github/workflows/release.yml` triggers only on a manually pushed `v*.*.*`
  tag. Versions must be hand-edited in three places in `pubspec.yaml`
  (`version:`, `msix_config.msix_version`, `flutter_to_debian.version`).
- `.github/workflows/publish-ms-store.yml` triggers on `release: published`.
  The release is created with `GITHUB_TOKEN`, and GitHub does **not** fire
  workflow events for actions performed with `GITHUB_TOKEN` — so the Store
  publish never triggers automatically. This is the core defect being fixed.
- Only one tag exists (`v1.0.2`); `pubspec.yaml` says `1.0.2+3`.
- There is no CI gate on pull requests.

## Decisions (agreed)

| Decision | Choice |
| --- | --- |
| Versioning | Conventional-commit SemVer via svu; **git tags are the source of truth**; version injected at build time, never committed back to `pubspec.yaml` |
| Release notes | AI-generated via Anthropic API (port of tws `gen-release-notes.sh`), commit-list fallback written first so notes can never block a release |
| Store publish | Manual approval gate via GitHub environment `ms-store` with required reviewers |
| Architecture | One workflow on push to `main`; no cross-workflow event chaining (eliminates the `GITHUB_TOKEN` bug by construction) |

## Architecture

Two workflows:

### 1. `ci.yml` — pull request gate (new)

On `pull_request`: `flutter pub get`, `flutter analyze`, `flutter test` on
ubuntu. Mirrors the tws MR build+test gate. Branch protection on `main` should
require it (documented in the setup guide, not enforceable from the repo).

### 2. `release.yml` — main pipeline (rewritten)

Trigger: `push: branches: [main]` plus `workflow_dispatch` for manual reruns.

Concurrency: `group: release-main`, `cancel-in-progress: false` — overlapping
merges queue and run serially so version computation and tagging never race.

Job graph:

```
version ─┬─ build-windows ─┬─ release ── publish-store (manual gate)
         ├─ build-linux ───┤
         ├─ notes ─────────┤
test ────┴─────────────────┘
```

#### `version` (ubuntu)

- Checkout with `fetch-depth: 0` (svu needs full history and tags).
- Run svu v3 (`ghcr.io/caarlos0/svu` container image):
  `svu next --always --tag.pattern 'v*'`.
  - Conventional commits drive the bump: `feat:` → minor, `fix:` → patch,
    `feat!:`/`BREAKING CHANGE` → major.
  - `--always` guarantees at least a patch bump, so every main commit yields a
    fresh version.
  - `--tag.pattern 'v*'` keeps non-version tags out of consideration.
- Job outputs: `version` (`x.y.z`), `msix_version` (`x.y.z.0`).

#### `test` (ubuntu)

`flutter pub get` + `flutter test`. Releases only ship from green builds.
(`flutter analyze` stays PR-only; main is post-merge.)

#### `build-windows` (windows, needs: version)

- Patch `pubspec.yaml` **in the workspace only** (not committed): set
  `version: <x.y.z>+<github run number>` and `msix_config.msix_version:
  <x.y.z.0>` via a small cross-platform patch script committed under `ci/`.
- `flutter build windows` → `flatplan-windows-<version>.zip`.
- `dart run msix:create --install-certificate false` → `.msix`.
- Upload zip + msix as job artifacts.

#### `build-linux` (ubuntu, needs: version)

- Same patch script: `version:` and `flutter_to_debian.version: <x.y.z>`.
- Existing steps preserved: `flutter build linux` → tar.gz; `flutter_to_debian`
  (with the existing dpkg-deb control-file wrapper) → `.deb`.
- Upload tar + deb as job artifacts.

#### `notes` (ubuntu, needs: version)

- Port of tws `ci/gen-release-notes.sh` → `ci/gen-release-notes.sh` here,
  adapted: audience is flatplan users (personal finance tracker), grouping by
  area is free-form (no Client/Server split), commit range is
  `<previous v* tag>..HEAD`.
- Behavior preserved from tws:
  - Writes the plain commit-list fallback **first**; only overwrites on a fully
    successful API call. The notes artifact always exists.
  - Gates: `RELEASE_NOTES_ENABLED` repo variable ≠ `true`, missing
    `ANTHROPIC_API_KEY`, curl/API failure, refusal → keep fallback, exit 0.
- `continue-on-error: true` on the job as a second belt-and-braces layer.
- Uploads `release-notes.md` artifact.

#### `release` (ubuntu, needs: version, test, build-windows, build-linux, notes)

- Download all artifacts.
- `softprops/action-gh-release@v2` with:
  - `tag_name: v<version>` — the action creates the tag on the built commit;
    this tag is svu's baseline for the next pipeline run.
  - `body_path: release-notes.md` (replaces `generate_release_notes: true`).
  - `files`: windows zip, msix, linux tar, deb.
- Uses the default `GITHUB_TOKEN` (`permissions: contents: write`). No PAT
  needed anywhere because nothing chains across workflows.

#### `publish-store` (ubuntu, needs: release)

- `environment: ms-store` — the GitHub environment carries **required
  reviewers**, so the job pauses until a human approves. Approving days later
  is fine; rejecting simply skips the Store for that release.
- Downloads the msix artifact (no release-asset download dance needed).
- `microsoft/store-submission@v1` with the five existing secrets:
  `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SELLER_ID`, `APP_ID`.
- The old "verify release commit is on main" check is dropped — the job runs
  only in the main pipeline by construction.

`publish-ms-store.yml` is **deleted**.

## Versioning details

- Source of truth: `v*` git tags. The `version:` line in the committed
  `pubspec.yaml` is vestigial (kept for local dev builds; may drift).
- Build number: `GITHUB_RUN_NUMBER` becomes the `+N` suffix in the patched
  pubspec version — monotonically increasing, no state to store.
- MSIX version is the strict 4-part `x.y.z.0` the Store requires.

## Error handling

| Failure | Behavior |
| --- | --- |
| Notes generation (API down, no key, refusal) | Fallback commit list ships; release proceeds |
| Test/build failure | No tag, no release, no Store submission |
| Store submission collides with a pending submission | Only `publish-store` fails; re-run the job after certification completes |
| Two merges close together | Concurrency group queues the second run; it computes its own fresh version after the first run's tag lands |
| Manual gate never approved | Release + GitHub assets exist; Store job eventually times out (GitHub default 30 days) with no side effects |

## Setup guide (new file: `docs/RELEASE_PIPELINE.md`)

Documents every external configuration item — what it is, where it comes from,
where to set it:

- **Repo secrets** (Settings → Secrets and variables → Actions → Secrets):
  - `ANTHROPIC_API_KEY` — from console.anthropic.com; used only by the notes job.
  - `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET` — Azure AD (Entra) app
    registration linked to Partner Center.
  - `SELLER_ID` — Partner Center → Account settings.
  - `APP_ID` — Partner Center Store app identity (product ID).
- **Repo variables** (same page → Variables): `RELEASE_NOTES_ENABLED`
  (optional kill switch, default on).
- **Environment** (Settings → Environments): create `ms-store`, add required
  reviewer(s). Optionally move the five Store secrets into this environment for
  least privilege.
- **Branch protection** (Settings → Branches): require the `ci.yml` check on
  `main`.
- Verification checklist: how to confirm the first pipeline run end-to-end.

## Testing

- Workflow YAML validated with `actionlint` locally before committing.
- `ci/gen-release-notes.sh` gets the same shape of guard behavior as tws
  (fallback-first); testable locally by running it with/without
  `ANTHROPIC_API_KEY`.
- The pubspec patch script is testable locally: run against the repo pubspec
  and diff the three version sites.
- True end-to-end verification happens on the first merge to `main`
  (documented as a checklist in the setup guide); the Store gate means the
  final step is safely observable before approving.

## Out of scope

- macOS builds/signing (repo has a `macos/` dir but no CI for it today).
- Publishing the `.deb` to any apt repository.
- Committing version bumps or changelog files back to the repo.
