# Release Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every push to `main` automatically versions (svu + conventional commits), tests, builds Windows/Linux artifacts, generates AI release notes, publishes a GitHub Release with a `v*` tag, and — behind a manual-approval environment gate — submits the MSIX to the Microsoft Store.

**Architecture:** One workflow (`release.yml`) on push to `main` runs the whole chain, so no cross-workflow event chaining is needed (this fixes the bug where `GITHUB_TOKEN`-created releases never trigger `on: release` workflows). A separate `ci.yml` gates pull requests. Git `v*` tags are the version source of truth; `pubspec.yaml` is patched in the CI workspace only. Spec: `docs/superpowers/specs/2026-07-20-release-pipeline-design.md`.

**Tech Stack:** GitHub Actions, Flutter (stable channel via `subosito/flutter-action@v2`), svu v3.2.4 (docker image `ghcr.io/caarlos0/svu:v3.2.4`), `softprops/action-gh-release@v2`, `microsoft/store-submission@v1`, Anthropic Messages API (curl + jq, POSIX sh), Dart (version patch script).

## Global Constraints

- Version tags are `v<semver>` (e.g. `v1.0.3`); svu invocation is exactly `svu next --always --tag.pattern 'v*'`.
- Pinned versions: `ghcr.io/caarlos0/svu:v3.2.4`, `actions/checkout@v4`, `subosito/flutter-action@v2` (channel `stable`, `cache: true`), `actions/upload-artifact@v4`, `actions/download-artifact@v4`, `softprops/action-gh-release@v2`, `microsoft/store-submission@v1`.
- The notes script must NEVER fail the pipeline: fallback file written first, every failure path exits 0.
- `pubspec.yaml` version patches happen only in the CI workspace — never committed.
- Release workflow concurrency: `group: release-main`, `cancel-in-progress: false`.
- Secrets used: `ANTHROPIC_API_KEY`, `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SELLER_ID`, `APP_ID`. Repo variable: `RELEASE_NOTES_ENABLED`.
- GitHub environment name for the Store gate: `ms-store`.
- Workflow YAML must pass actionlint: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color`.
- Work on branch `feat/release-pipeline`; commit after each task.

---

### Task 1: Version patch script (`ci/patch_version.dart`)

**Files:**
- Create: `ci/patch_version.dart`
- Test: `test/patch_version_test.dart`

**Interfaces:**
- Produces: `String patchPubspec(String content, String version, int buildNumber)` — pure function, throws `FormatException` if any of the three version sites is missing. CLI: `dart run ci/patch_version.dart <x.y.z> <build-number> [pubspec-path]` (default path `pubspec.yaml`). Task 4's workflow calls the CLI form.

The three sites in `pubspec.yaml` (current lines 19, 84, 90):
- `version: 1.0.2+3` (column 0) → `version: <x.y.z>+<build>`
- `  msix_version: "1.0.2.0"` (under `msix_config:`) → `  msix_version: "<x.y.z>.0"`
- `  version: "1.0.2"` (under `flutter_to_debian:`, the only two-space-indented `version:` line) → `  version: "<x.y.z>"`

- [ ] **Step 1: Create branch**

```bash
git checkout -b feat/release-pipeline
```

- [ ] **Step 2: Write the failing test**

Create `test/patch_version_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../ci/patch_version.dart';

const sample = '''
version: 1.0.2+3

dependencies:
  flutter:
    sdk: flutter

msix_config:
  display_name: "flatplan"
  msix_version: "1.0.2.0"
  install_certificate: false

flutter_to_debian:
  name: "flatplan"
  version: "1.0.2"
  maintainer: "felements"
''';

void main() {
  test('patches all three version sites', () {
    final lines = patchPubspec(sample, '2.3.4', 57).split('\n');
    expect(lines, contains('version: 2.3.4+57'));
    expect(lines, contains('  msix_version: "2.3.4.0"'));
    expect(lines, contains('  version: "2.3.4"'));
  });

  test('leaves unrelated lines untouched', () {
    final out = patchPubspec(sample, '2.3.4', 57);
    expect(out, contains('  display_name: "flatplan"'));
    expect(out, contains('  maintainer: "felements"'));
  });

  test('throws when a version site is missing', () {
    expect(
      () => patchPubspec('name: flatplan\n', '2.3.4', 1),
      throwsFormatException,
    );
  });

  test('patches the real pubspec.yaml', () {
    final real = File('pubspec.yaml').readAsStringSync();
    final lines = patchPubspec(real, '9.9.9', 42).split('\n');
    expect(lines, contains('version: 9.9.9+42'));
    expect(lines, contains('  msix_version: "9.9.9.0"'));
    expect(lines, contains('  version: "9.9.9"'));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/patch_version_test.dart`
Expected: FAIL — cannot resolve `../ci/patch_version.dart` (file does not exist).

- [ ] **Step 4: Write the implementation**

Create `ci/patch_version.dart`:

```dart
// Patches the three version sites in pubspec.yaml at CI build time; the repo
// copy is never committed with these changes (git tags are the version source
// of truth — see docs/superpowers/specs/2026-07-20-release-pipeline-design.md).
// Usage: dart run ci/patch_version.dart <x.y.z> <build-number> [pubspec-path]
import 'dart:io';

String patchPubspec(String content, String version, int buildNumber) {
  final sites = <String, (RegExp, String)>{
    'version': (
      RegExp(r'^version: .+$', multiLine: true),
      'version: $version+$buildNumber',
    ),
    'msix_config.msix_version': (
      RegExp(r'^  msix_version: .+$', multiLine: true),
      '  msix_version: "$version.0"',
    ),
    'flutter_to_debian.version': (
      RegExp(r'^  version: .+$', multiLine: true),
      '  version: "$version"',
    ),
  };
  var result = content;
  sites.forEach((name, site) {
    final (pattern, replacement) = site;
    if (!pattern.hasMatch(result)) {
      throw FormatException('version site not found in pubspec: $name');
    }
    result = result.replaceFirst(pattern, replacement);
  });
  return result;
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
        'usage: dart run ci/patch_version.dart <x.y.z> <build-number> [pubspec-path]');
    exit(2);
  }
  final version = args[0];
  final buildNumber = int.parse(args[1]);
  final path = args.length > 2 ? args[2] : 'pubspec.yaml';
  final file = File(path);
  file.writeAsStringSync(patchPubspec(file.readAsStringSync(), version, buildNumber));
  stdout.writeln('patched $path: version=$version+$buildNumber msix=$version.0');
}
```

Note: `^  version:` matches only the `flutter_to_debian` entry — `msix_config` has no two-space `version:` key. The real-pubspec test in Step 2 guards this assumption.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/patch_version_test.dart`
Expected: all 4 tests PASS.

- [ ] **Step 6: Run the CLI once against a scratch copy**

```bash
cp pubspec.yaml /tmp/claude-1000/-home-frame-projects-flatplan/0da42c3d-1e48-4a09-8e31-26f8973185da/scratchpad/pubspec.yaml
dart run ci/patch_version.dart 3.2.1 7 /tmp/claude-1000/-home-frame-projects-flatplan/0da42c3d-1e48-4a09-8e31-26f8973185da/scratchpad/pubspec.yaml
grep -n 'version\|msix_version' /tmp/claude-1000/-home-frame-projects-flatplan/0da42c3d-1e48-4a09-8e31-26f8973185da/scratchpad/pubspec.yaml | grep '3.2.1'
```

Expected: three lines showing `version: 3.2.1+7`, `msix_version: "3.2.1.0"`, `version: "3.2.1"`.

- [ ] **Step 7: Commit**

```bash
git add ci/patch_version.dart test/patch_version_test.dart
git commit -m "feat: add CI pubspec version patch script"
```

---

### Task 2: Release notes script (`ci/gen-release-notes.sh`)

**Files:**
- Create: `ci/gen-release-notes.sh`

**Interfaces:**
- Consumes: env vars `PRODUCT_VERSION` (x.y.z), `ANTHROPIC_API_KEY` (optional), `RELEASE_NOTES_ENABLED` (default `true`), `RELEASE_NOTES_OUT` (default `release-notes.md`), `ANTHROPIC_MODEL` (default `claude-sonnet-5`), `CONTEXT_DOC` (default `README.md`).
- Produces: the file at `$RELEASE_NOTES_OUT` — AI notes on success, plain commit list otherwise. Always exits 0. Task 4's `notes` job runs `sh ci/gen-release-notes.sh`.

Port of `tws.game.poc/ci/gen-release-notes.sh` with a flatplan-specific system prompt (end users of a personal finance tracker) and README.md as domain-vocabulary context.

- [ ] **Step 1: Write the script**

Create `ci/gen-release-notes.sh`:

```sh
#!/usr/bin/env sh
# Generate release notes for the commit range since the previous v* tag via
# the Anthropic API. NEVER fails the pipeline: writes a plain commit-list
# fallback FIRST, then only overwrites it on a fully successful API call.
# Design: docs/superpowers/specs/2026-07-20-release-pipeline-design.md
set +e  # a single command's non-zero must never abort the script

VERSION="${PRODUCT_VERSION:-0.0.0}"
OUT="${RELEASE_NOTES_OUT:-release-notes.md}"
CONTEXT_DOC="${CONTEXT_DOC:-README.md}"
MODEL="${ANTHROPIC_MODEL:-claude-sonnet-5}"
ENABLED="${RELEASE_NOTES_ENABLED:-true}"
CURL_BIN="${CURL_BIN:-curl}"

mkdir -p "$(dirname "$OUT")" 2>/dev/null

# --- commit range: previous v* tag .. HEAD --------------------------------
PREV_TAG="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null)"
if [ -n "$PREV_TAG" ]; then RANGE="$PREV_TAG..HEAD"; else RANGE="HEAD"; fi
COMMITS="$(git log --no-merges --format='- %s' "$RANGE" 2>/dev/null)"
[ -z "$COMMITS" ] && COMMITS="- (no changes since previous release)"

# --- fallback FIRST: the artifact always exists ---------------------------
printf '## flatplan v%s\n\n%s\n' "$VERSION" "$COMMITS" > "$OUT"

# --- gates: disabled / no key / no jq -> keep fallback --------------------
if [ "$ENABLED" != "true" ]; then
  echo "release-notes: disabled via RELEASE_NOTES_ENABLED; using fallback."; exit 0
fi
if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "release-notes: ANTHROPIC_API_KEY unset; using fallback."; exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "release-notes: jq not found; using fallback."; exit 0
fi

# --- request body (jq -n escapes everything) ------------------------------
CONTEXT_TEXT=""; [ -f "$CONTEXT_DOC" ] && CONTEXT_TEXT="$(cat "$CONTEXT_DOC")"
SYSTEM='You write short release notes for flatplan, a simple personal finance tracker desktop app for Windows and Linux. Audience: end users first (plain language: what changed and why it matters to someone tracking their budget), developers second. Use the supplied product README only for domain vocabulary. Output GitHub-flavored Markdown ONLY, no preamble, in exactly this shape: one lead sentence summarizing the release; then 3-6 bullet points in plain user language; then a final line beginning "**In this build:**" with a terse technical summary for developers. Docs handling: do NOT add bullets for documentation churn — most doc commits are AI-authored specs, plans, and brainstorming notes (e.g. under docs/superpowers/) and are noise to users; only mention documentation when a user-facing document changed substantively. Do not invent anything not present in the commit list. Emit the Markdown directly as raw text; do NOT wrap the whole response in a fenced code block.'

REQ="$(jq -n \
  --arg model "$MODEL" --arg system "$SYSTEM" \
  --arg context "$CONTEXT_TEXT" --arg version "$VERSION" --arg commits "$COMMITS" \
  '{
     model: $model,
     max_tokens: 1024,
     thinking: {type: "disabled"},
     output_config: {effort: "low"},
     system: $system,
     messages: [ { role: "user", content:
       ("Release version: v" + $version
        + "\n\nProduct README (vocabulary only):\n" + $context
        + "\n\nCommits since the previous release:\n" + $commits) } ]
   }')"
if [ -z "$REQ" ]; then
  echo "release-notes: failed to build request JSON; using fallback."; exit 0
fi

# --- call the API; any non-2xx -> fallback --------------------------------
BODY="$(mktemp)"
HTTP="$("$CURL_BIN" -sS -o "$BODY" -w '%{http_code}' --max-time 120 \
  https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$REQ" 2>/dev/null)"
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "release-notes: curl failed (rc=$RC); using fallback."; rm -f "$BODY"; exit 0
fi
case "$HTTP" in
  2*) : ;;
  *)  echo "release-notes: API HTTP $HTTP; using fallback."; head -c 400 "$BODY" 2>/dev/null; echo
      rm -f "$BODY"; exit 0 ;;
esac

STOP="$(jq -r '.stop_reason // empty' "$BODY" 2>/dev/null)"
TEXT="$(jq -r '[.content[]? | select(.type=="text") | .text] | join("\n") // empty' "$BODY" 2>/dev/null)"
rm -f "$BODY"
if [ "$STOP" = "refusal" ] || [ -z "$TEXT" ]; then
  echo "release-notes: no usable text (stop_reason=$STOP); using fallback."; exit 0
fi

# --- success: overwrite the fallback --------------------------------------
printf '%s\n' "$TEXT" > "$OUT"
echo "release-notes: generated via $MODEL."
exit 0
```

Then: `chmod +x ci/gen-release-notes.sh`

- [ ] **Step 2: Verify fallback path (no API key)**

```bash
env -u ANTHROPIC_API_KEY PRODUCT_VERSION=9.9.9 \
  RELEASE_NOTES_OUT=/tmp/claude-1000/-home-frame-projects-flatplan/0da42c3d-1e48-4a09-8e31-26f8973185da/scratchpad/notes.md \
  sh ci/gen-release-notes.sh; echo "exit=$?"
head -5 /tmp/claude-1000/-home-frame-projects-flatplan/0da42c3d-1e48-4a09-8e31-26f8973185da/scratchpad/notes.md
```

Expected: prints `release-notes: ANTHROPIC_API_KEY unset; using fallback.` then `exit=0`; file starts with `## flatplan v9.9.9` followed by a `- <commit subject>` list.

- [ ] **Step 3: Verify disabled path**

```bash
RELEASE_NOTES_ENABLED=false PRODUCT_VERSION=9.9.9 \
  RELEASE_NOTES_OUT=/tmp/claude-1000/-home-frame-projects-flatplan/0da42c3d-1e48-4a09-8e31-26f8973185da/scratchpad/notes2.md \
  sh ci/gen-release-notes.sh; echo "exit=$?"
```

Expected: `release-notes: disabled via RELEASE_NOTES_ENABLED; using fallback.` and `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add ci/gen-release-notes.sh
git commit -m "feat: add AI release notes generator with commit-list fallback"
```

---

### Task 3: PR gate workflow (`.github/workflows/ci.yml`)

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: a required-check candidate named `test` on pull requests. Independent of Task 4.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test
```

- [ ] **Step 2: Lint the workflow**

Run: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color`
Expected: no output (exit 0). Note: this lints all workflows; pre-existing files must also be clean or errors clearly attributable to untouched files.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add pull request analyze+test gate"
```

---

### Task 4: Main release workflow (rewrite `release.yml`, delete `publish-ms-store.yml`)

**Files:**
- Rewrite: `.github/workflows/release.yml`
- Delete: `.github/workflows/publish-ms-store.yml`

**Interfaces:**
- Consumes: `dart run ci/patch_version.dart <version> <build>` (Task 1), `sh ci/gen-release-notes.sh` (Task 2), secrets/variables listed in Global Constraints.
- Produces: GitHub Release + tag `v<version>` with 4 assets; Store submission gated by environment `ms-store`.

- [ ] **Step 1: Replace `.github/workflows/release.yml` entirely with:**

```yaml
name: Release

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: release-main
  cancel-in-progress: false

jobs:
  version:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.svu.outputs.version }}
    steps:
      - name: Checkout repository (full history for svu)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Compute next version with svu
        id: svu
        run: |
          VERSION="$(docker run --rm -v "$PWD:/repo" -w /repo \
            ghcr.io/caarlos0/svu:v3.2.4 next --always --tag.pattern 'v*' | sed 's/^v//')"
          echo "computed version: $VERSION"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"

  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Test
        run: flutter test

  build-windows:
    runs-on: windows-latest
    needs: version
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Patch version into pubspec
        run: dart run ci/patch_version.dart ${{ needs.version.outputs.version }} ${{ github.run_number }}

      - name: Build Windows
        run: flutter build windows

      - name: Create ZIP
        run: |
          Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "flatplan-windows-${{ needs.version.outputs.version }}.zip"

      - name: Build MSIX
        run: dart run msix:create --install-certificate false

      - name: Upload Windows ZIP Artifact
        uses: actions/upload-artifact@v4
        with:
          name: flatplan-windows-zip
          path: flatplan-windows-*.zip

      - name: Upload Windows MSIX Artifact
        uses: actions/upload-artifact@v4
        with:
          name: flatplan-windows-msix
          path: "build\\windows\\x64\\runner\\Release\\*.msix"

  build-linux:
    runs-on: ubuntu-latest
    needs: version
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Linux dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Patch version into pubspec
        run: dart run ci/patch_version.dart ${{ needs.version.outputs.version }} ${{ github.run_number }}

      - name: Build Linux
        run: flutter build linux

      - name: Create Tar
        run: tar -czvf flatplan-linux-${{ needs.version.outputs.version }}.tar.gz -C build/linux/x64/release/bundle .

      - name: Build Debian Package
        run: |
          # Create a wrapper around dpkg-deb to patch the control file before building
          sudo mv /usr/bin/dpkg-deb /usr/bin/dpkg-deb.real
          cat << 'EOF' > dpkg-deb
          #!/bin/bash
          if [[ "$1" == "--build" ]]; then
            CONTROL_FILE="$2/DEBIAN/control"
            if [[ -f "$CONTROL_FILE" ]]; then
              perl -pi -e 'if (/^Depends:\s*(.*)/) { my @deps = split(/,\s*/, $1); @deps = grep { $_ !~ /\s/ && $_ !~ /^$/ } @deps; if (@deps) { $_ = "Depends: " . join(", ", @deps) . "\n"; } else { $_ = ""; } }' "$CONTROL_FILE"
            fi
          fi
          /usr/bin/dpkg-deb.real "$@"
          EOF
          chmod +x dpkg-deb
          sudo mv dpkg-deb /usr/bin/dpkg-deb

          dart run flutter_to_debian

      - name: Upload Linux Tar Artifact
        uses: actions/upload-artifact@v4
        with:
          name: flatplan-linux-tar
          path: flatplan-linux-*.tar.gz

      - name: Upload Linux DEB Artifact
        uses: actions/upload-artifact@v4
        with:
          name: flatplan-linux-deb
          path: "**/*.deb"

  notes:
    runs-on: ubuntu-latest
    needs: version
    continue-on-error: true
    steps:
      - name: Checkout repository (full history for commit range)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate release notes
        env:
          PRODUCT_VERSION: ${{ needs.version.outputs.version }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          RELEASE_NOTES_ENABLED: ${{ vars.RELEASE_NOTES_ENABLED || 'true' }}
        run: |
          sh ci/gen-release-notes.sh
          echo "----- release-notes.md -----"
          cat release-notes.md

      - name: Upload release notes
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: release-notes
          path: release-notes.md

  release:
    runs-on: ubuntu-latest
    needs: [version, test, build-windows, build-linux, notes]
    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Prepare release files
        run: |
          mkdir -p release-files
          find artifacts -name "flatplan-windows-*.zip" -exec cp {} release-files/ \;
          find artifacts -name "*.msix" -exec cp {} release-files/ \;
          find artifacts -name "flatplan-linux-*.tar.gz" -exec cp {} release-files/ \;
          find artifacts -name "*.deb" -exec cp {} release-files/ \;
          ls -la release-files

      - name: Ensure release notes exist
        run: |
          if [ ! -f artifacts/release-notes/release-notes.md ]; then
            mkdir -p artifacts/release-notes
            echo "flatplan v${{ needs.version.outputs.version }}" > artifacts/release-notes/release-notes.md
          fi

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: v${{ needs.version.outputs.version }}
          name: flatplan v${{ needs.version.outputs.version }}
          body_path: artifacts/release-notes/release-notes.md
          files: release-files/*
          draft: false

  publish-store:
    runs-on: ubuntu-latest
    needs: release
    environment: ms-store
    steps:
      - name: Download MSIX artifact
        uses: actions/download-artifact@v4
        with:
          name: flatplan-windows-msix

      - name: Locate MSIX
        run: |
          MSIX_FILE=$(ls *.msix | head -n 1)
          if [ -z "$MSIX_FILE" ]; then
            echo "::error::Could not find .msix artifact"
            exit 1
          fi
          echo "MSIX_PATH=$MSIX_FILE" >> "$GITHUB_ENV"

      - name: Publish MSIX to Microsoft Store
        uses: microsoft/store-submission@v1
        with:
          tenant-id: ${{ secrets.TENANT_ID }}
          client-id: ${{ secrets.CLIENT_ID }}
          client-secret: ${{ secrets.CLIENT_SECRET }}
          seller-id: ${{ secrets.SELLER_ID }}
          app-id: ${{ secrets.APP_ID }}
          package-path: ${{ env.MSIX_PATH }}
```

Notes on intentional details (do not "simplify" them away):
- `notes` job has `continue-on-error: true` AND the script itself always exits 0 — belt and braces; the `release` job additionally synthesizes a minimal notes file if the artifact is absent.
- `softprops/action-gh-release@v2` creates the `v<version>` tag at the workflow's commit — that tag is svu's baseline for the next run. `generate_release_notes` is intentionally NOT set (body comes from `body_path`).
- The svu step pipes through `sed 's/^v//'` because svu prints `v1.2.3`.
- `publish-store` runs in the same workflow, so the old cross-workflow `release: published` trigger (broken with `GITHUB_TOKEN`) is gone by construction; the old "verify commit on main" check is unnecessary because the workflow only triggers on `main`.

- [ ] **Step 2: Delete the obsolete workflow**

```bash
git rm .github/workflows/publish-ms-store.yml
```

- [ ] **Step 3: Lint all workflows**

Run: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color`
Expected: exit 0, no findings.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: rewrite release pipeline to run on every main push

Version via svu (conventional commits), AI release notes with fallback,
GitHub Release + v-tag, and MS Store submission behind the ms-store
environment gate. Deletes publish-ms-store.yml: releases created with
GITHUB_TOKEN never fire the release:published event, so that workflow
never triggered; running everything in one workflow removes the chaining
entirely."
```

---

### Task 5: Setup guide (`docs/RELEASE_PIPELINE.md`)

**Files:**
- Create: `docs/RELEASE_PIPELINE.md`

**Interfaces:**
- Consumes: names of secrets/variables/environment from Task 4 (must match exactly: `ANTHROPIC_API_KEY`, `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SELLER_ID`, `APP_ID`, `RELEASE_NOTES_ENABLED`, environment `ms-store`).

- [ ] **Step 1: Write the guide**

Create `docs/RELEASE_PIPELINE.md`:

```markdown
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
```

- [ ] **Step 2: Final verification — full test suite and lint**

```bash
flutter test
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color
```

Expected: all tests pass; actionlint exits 0.

- [ ] **Step 3: Commit**

```bash
git add docs/RELEASE_PIPELINE.md
git commit -m "docs: add release pipeline setup guide"
```

---

## After the plan

Use superpowers:finishing-a-development-branch — push `feat/release-pipeline`, open a PR to `main` (its merge is the pipeline's first live run once secrets/environment are configured). Remind the user to complete `docs/RELEASE_PIPELINE.md` §One-time repository setup **before** merging, or the first run will ship fallback notes and the Store job will fail at the credentials step.
