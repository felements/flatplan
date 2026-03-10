# Contributing to Flatplan

Thank you for your interest in contributing! Flatplan is a community-driven project and every contribution matters — from bug reports and documentation improvements to new features.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Commit Message Convention](#commit-message-convention)
- [Merge Request Process](#merge-request-process)
- [Coding Standards](#coding-standards)

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold these standards. Please report unacceptable behaviour to the maintainers via the [issue tracker](https://github.com/felements/flatplan/issues).

---

## How Can I Contribute?

### 🐛 Reporting Bugs

1. **Search first** — check [existing issues](https://github.com/felements/flatplan/issues) to avoid duplicates.
2. Open a new issue using the **Bug Report** template.
3. Provide: OS + version, steps to reproduce, expected vs. actual behaviour, and any relevant log output.

### 💡 Suggesting Features

1. Open an issue using the **Feature Request** template.
2. Describe the problem you're trying to solve and your proposed solution.
3. Discuss the idea before writing code — this saves everyone's time.

### 📝 Improving Documentation

Docs live in the `doc/` folder and in the root `README.md`. Fixes, clarifications, and translations are all welcome.

### 🔧 Submitting Code

- Pick an open issue labelled `good first issue` or `help wanted`.
- Comment on the issue to let others know you're working on it.
- Follow the [Development Setup](#development-setup) guide below.

---

## Development Setup

### Prerequisites

| Tool | Minimum version |
|------|----------------|
| Flutter | 3.32+ |
| Dart | 3.11+ |
| A desktop target (Linux, macOS, or Windows) | — |

### Steps

```bash
# 1. Fork the repo on GitHub, then clone your fork
git clone git@github.com:<your-username>/flatplan.git
cd flatplan

# 2. Install dependencies
flutter pub get

# 3. Regenerate code (freezed / riverpod / json_serializable)
dart run build_runner build --delete-conflicting-outputs

# 4. Run the app on your desktop
flutter run -d linux   # or macos / windows
```

### Running Tests

```bash
flutter test
```

---

## Commit Message Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>
```

| Type | When to use |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation-only changes |
| `refactor` | Code change that is neither a fix nor a feature |
| `test` | Adding or correcting tests |
| `chore` | Build process, dependency updates, tooling |

**Examples:**
```
feat(category): add drag-to-reorder categories
fix(storage): handle missing period YAML gracefully
docs(readme): add screenshot to getting started section
```

---

## Merge Request Process

1. **Branch naming:** `feat/<short-description>`, `fix/<short-description>`, `docs/<short-description>`.
2. Keep MRs focused — one logical change per MR.
3. Make sure `flutter test` passes and there are no new lint warnings (`flutter analyze`).
4. Fill in the MR template; link the related issue with `Closes #<issue-number>`.
5. A maintainer will review within a few days. Be ready to iterate.
6. MRs are merged via **squash** to keep the history clean.

---

## Coding Standards

- Follow the [Flutter style guide](https://docs.flutter.dev/perf/best-practices) and the rules in `analysis_options.yaml`.
- State management: **Riverpod** (already in use) — do not introduce Bloc or GetX.
- Data models: **Freezed** + `json_annotation` — keep the existing pattern.
- Keep files under ~200 lines; split into smaller widgets/classes when they grow.
- Prefer `const` constructors everywhere possible.
- No `print()` — use `dart:developer` `log()`.
- All public APIs must have `///` doc comments.

---

Thank you again for helping make Flatplan better! 🎉
