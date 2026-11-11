# Changelog

All notable changes to **Flatplan** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Vaults: keep several named folders of period files and switch between them from the sidebar. Manage them under Settings → Vaults. The existing folder becomes the first vault automatically.
- Storage abstraction and a sync engine (local mirror, persisted change journal, newest-wins conflict handling with side files) preparing for remote vaults on GitLab, GitHub, WebDAV, S3 and Google Drive.
- "Edit Period" in the dashboard's period menu renames a period and moves its start date. Days another period starts on cannot be picked, and a date that moves the period past a neighbour shows a warning before saving.
- An "Over Budget" card on the dashboard, between Total Spent and Free Money, sums what each category has spent beyond its own limit. Only overshoots count, so a category under its limit no longer hides one over it. The subtitle counts the categories over limit, and the AI stats export states the same figure.
- Payment tags: write `#renovation` (or several tags) anywhere in a payment's comment. On the category screen the tags move out of the text and show as chips after it.
- A "Top tags" card on the dashboard lists the three most-spent tags of the period, each with its sum this period and across all periods. A payment with several tags counts in full under each.
- A Stats page (sidebar → Stats) graphs recorded spending and income period by period. Tick All, any category or any tag — several at once — and choose all periods or a from–to month range. A ticked category also shows its limit in each period as a stepped dashed line.
- On the Stats page, click a dot to list the payments behind it under the graph: date, comment with its tag chips, category and amount, oldest first. Click the dot again or ✕ to close the list. The legend shows each line's total over the periods on the chart.

### Changed
- "Change Folder" and "Reset to default folder" moved into the vault's edit form.
- Period creation moved out of Settings: a "+ Next period" button under Today in the sidebar creates the first period of an empty vault or rolls the current one over. The dashboard's empty state opens the same dialog directly. The rollover dialog now says which period's categories and recurring planned payments carry over.
- On the category screen, a planned payment that is overdue in the current period shows its due day and clock icon in the same red as the dashboard tile's dot, so the list says which payment needs attention. Finished periods, paid payments and payments not yet due keep the muted grey.
- A finished period's daily-allowance categories show how the period was paced — "averaged €35/day of €40/day planned", in red when spending ran ahead of plan — on the dashboard tile and the category screen, in place of a meaningless "/ day left".

### Fixed
- A planned payment set to a day of the month is now placed within its own period. In the last days of a period (after the calendar month turns), a payment due earlier in the period, such as the 25th, used to move to next month's 25th — hidden from the AI stats export and never shown as overdue. It now stays on the 25th of the period's start month and flags as overdue if unpaid.
- Stats graph: amounts of six figures or more (250,000) no longer wrap onto two lines on the left axis; the axis widens to fit its longest label.
- A payment comment starting with `#` was erased on save, and a comment containing a double quote could make the whole period file unreadable. Such values are now quoted properly; files without them are written exactly as before.

### Planned
- Multi-currency support
- Improved charts and visualisations
- Data export (CSV / PDF)

---

## [1.0.2] — 2026-03-15

### Fixed
- Fixed initial folder path generation for cold start. Resolved an issue where the `flatplan` folder was duplicated in the application support directory pathway (e.g. `c:\Users\{user}\AppData\Roaming\felements\flatplan/flatplan/periods`) by correctly using the platform-specific separator and ignoring the redundant folder creation.

---

## [1.0.1] — 2026-03-12

### Fixed
- Default data directory now uses the system application-support folder instead of the executable's parent directory. Fixes `PathAccessException` crash on MSIX-packaged Windows builds (Microsoft Store).

---

## [1.0.0] — 2026-03-07

### Added
- Initial public release 🎉
- Local YAML file storage — one file per budget period.
- Dashboard view with Plan vs. Fact summary cards.
- Category management with spending limits and heat indicators.
- Planned expense entry with optional due dates.
- Fact expense recording per category.
- Period rollover — copy previous period's plan to a new one.
- Cold-start bootstrap for first-time users.
- Daily allowance calculation ("free-to-spend per day").
- Custom data folder via Settings (file picker).
- Dark and light theme support with the Outfit typeface.
- Desktop targets: **Linux**, **macOS**, **Windows**.

---

[Unreleased]: https://github.com/felements/flatplan/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/felements/flatplan/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/felements/flatplan/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/felements/flatplan/releases/tag/v1.0.0
