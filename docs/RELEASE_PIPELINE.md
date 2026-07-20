# Release Pipeline Setup

Every push to `main` runs `.github/workflows/release.yml`: it computes the
next version from git history, tests, builds Windows (zip + MSIX) and Linux
(tar + deb), generates release notes, publishes a GitHub Release tagged
`v<version>`, and — after a manual approval — submits the MSIX to the
Microsoft Store. Pull requests are gated by `.github/workflows/ci.yml`
(analyze + test).

Design: `docs/superpowers/specs/2026-07-20-release-pipeline-design.md`.

## How versioning works

- Git `v*` tags are the source of truth. The `version:` in `pubspec.yaml` is
  only used for local dev builds and is patched (not committed) in CI.
- [svu](https://github.com/caarlos0/svu) reads the latest `v*` tag and bumps
  it from conventional commit messages: `feat:` → minor, `fix:` → patch,
  `feat!:` / `BREAKING CHANGE:` → major. Any other commit still gets a patch
  bump (`--always`), so every merge to `main` produces a release.
- The release job creates the `v<version>` tag, which becomes the baseline
  for the next run.

## One-time repository setup

### 1. Repository secrets

Settings → Secrets and variables → Actions → **Secrets** → "New repository
secret":

| Secret | Used by | Where to get it |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | release notes job | [console.anthropic.com](https://console.anthropic.com) → API Keys. Optional: without it, releases ship a plain commit list. |
| `TENANT_ID` | Store publish | Entra admin center → the app registration's **Directory (tenant) ID**. |
| `CLIENT_ID` | Store publish | Same app registration's **Application (client) ID**. |
| `CLIENT_SECRET` | Store publish | App registration → Certificates & secrets → new client secret (copy the **value**, not the ID). Note the expiry — rotate before it lapses. |
| `SELLER_ID` | Store publish | Partner Center → Account settings → Organization profile → Legal info → **Seller ID**. |
| `APP_ID` | Store publish | Partner Center → Apps and games → flatplan → Product identity → **Store ID** (e.g. `9NBLGGH4R315`). |

The Azure AD (Entra) app registration must be associated with the Partner
Center account: Partner Center → Account settings → User management →
Microsoft Entra applications → add the app with **Manager** role.

### 2. Repository variables (optional)

Same page → **Variables**:

| Variable | Default | Purpose |
| --- | --- | --- |
| `RELEASE_NOTES_ENABLED` | `true` | Set to `false` to skip the Anthropic API call and ship the commit-list fallback. |

### 3. `ms-store` environment (the manual gate)

Settings → Environments → "New environment" → name it exactly `ms-store`:

- Enable **Required reviewers** and add yourself (and/or other maintainers).
- Result: after each release is published, the `publish-store` job waits for
  an approval click (Actions → the run → "Review deployments"). Approving
  days later is fine. Rejecting skips the Store for that release only.
- Optional hardening: move the five Store secrets from repository secrets
  into this environment's secrets so only the gated job can read them.

Why the gate: the Store allows only one pending submission at a time and
each goes through certification (hours–days), so back-to-back merges would
collide. Approve when the previous submission has cleared.

### 4. Branch protection (recommended)

Settings → Branches → rule for `main`: require the `test` check from the CI
workflow before merging.

## First-run verification checklist

1. Merge this pipeline to `main` (or trigger via Actions →
   Release → "Run workflow").
2. Watch the run: `version` prints the computed version; `test`,
   `build-windows`, `build-linux`, `notes` run in parallel.
3. After `release`: check the repo's Releases page — new `v<version>`
   release with 4 assets and readable notes.
4. `publish-store` shows "Waiting for review" — approve it.
5. Confirm the submission appears in Partner Center → flatplan →
   Submissions.

## Failure modes

| Symptom | Cause / fix |
| --- | --- |
| Notes are a plain commit list | `ANTHROPIC_API_KEY` missing/invalid, API error, or `RELEASE_NOTES_ENABLED=false`. Never blocks the release. |
| `publish-store` fails with a pending-submission error | Previous submission still in certification. Re-run the job (Actions → run → re-run failed jobs) after it clears. |
| Wrong version bump | Check commit messages follow conventional commits; svu only reads `feat`/`fix`/breaking markers. |
| Release exists but Store job was rejected/expired | Re-run the `publish-store` job from the same run, or trigger workflow_dispatch (builds a fresh patch release). |
