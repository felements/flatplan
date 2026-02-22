---
description: Generate a commit message following the Conventional Commits 1.0.0 specification
---

# Conventional Commits — Commit Message Generation

When asked to generate a commit message (e.g. via `/commit-message`), follow the rules below **exactly**.

## Message Structure

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Rules

### Type (REQUIRED)
Use one of the following **lowercase** types as the first word:

| Type         | When to use                                                        |
|--------------|--------------------------------------------------------------------|
| `feat`       | A new feature is added to the application                          |
| `fix`        | A bug fix                                                          |
| `docs`       | Documentation-only changes                                        |
| `style`      | Changes that do not affect meaning (whitespace, formatting, etc.)  |
| `refactor`   | Code change that neither fixes a bug nor adds a feature            |
| `perf`       | A code change that improves performance                            |
| `test`       | Adding or correcting tests                                        |
| `build`      | Changes to the build system or external dependencies               |
| `ci`         | Changes to CI configuration files and scripts                      |
| `chore`      | Other changes that don't modify `src` or `test` files              |
| `revert`     | Reverts a previous commit                                         |

### Scope (OPTIONAL)
- A noun in parentheses immediately after the type, describing the section of the codebase affected.
- Examples: `feat(models):`, `fix(storage):`, `refactor(providers):`

### Breaking Change Indicator (OPTIONAL)
- Append `!` immediately before the `:` to flag a breaking change.
- Example: `feat(api)!: remove deprecated endpoint`

### Description (REQUIRED)
- Immediately follows the `: ` (colon + space).
- Use the **imperative, present tense** ("add", not "added" or "adds").
- Do **not** capitalize the first letter.
- Do **not** end with a period.
- Keep it concise — ideally under 72 characters for the entire first line.

### Body (OPTIONAL)
- Separated from the description by **one blank line**.
- Free-form text providing additional context on **what** changed and **why**.
- Wrap lines at 72 characters.

### Footer(s) (OPTIONAL)
- Separated from the body (or description if no body) by **one blank line**.
- Each footer is a token followed by `:<space>` or `<space>#` and then a value.
- Use `-` in place of spaces in footer tokens (e.g., `Reviewed-by`, `Refs`).
- **`BREAKING CHANGE:`** must be uppercase and followed by a space and description.
  - `BREAKING-CHANGE:` is synonymous with `BREAKING CHANGE:`.

## Process

1. **Inspect the staged changes** — run `git diff --cached --stat` and `git diff --cached` to understand what changed.
2. **Determine the type** — pick the most appropriate type from the table above based on the nature of the changes.
3. **Determine the scope** — if all changes are in one logical area (e.g., `models`, `storage`, `views`), include a scope. Omit it if changes span many areas.
4. **Write the description** — summarise the change in imperative present tense.
5. **Write a body** — if the diff is non-trivial, add a body explaining the motivation and what changed.
6. **Add footers** — include `BREAKING CHANGE:` if applicable. Add `Refs: #<issue>` if an issue number is known.
7. **Present the message** — output the full commit message inside a fenced code block for the user to review.

## Examples

### Simple bug fix
```
fix(storage): handle missing directory on first launch
```

### Feature with scope
```
feat(views): add period selector dropdown to dashboard
```

### Breaking change with body and footer
```
feat(models)!: replace category id with uuid

Migrate all category identifiers from sequential integers to UUIDs
to support cross-device sync. Existing period files will need to be
migrated.

BREAKING CHANGE: category `id` field is now a UUID string instead of int
```

### Docs change
```
docs: update README with build instructions
```

### Multi-scope refactor (no scope)
```
refactor: extract shared validation logic into helpers
```

### Revert
```
revert: feat(views): add period selector dropdown to dashboard

This reverts commit abc1234.
```
