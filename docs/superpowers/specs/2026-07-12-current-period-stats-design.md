# Current-period stats file for AI insights

**Date:** 2026-07-12
**Status:** Approved

## Problem

A later feature will run a periodic job that reads the current period's state and asks
an LLM (Sonnet 5) for daily spending insights. That job needs a single, always-current,
readable snapshot of "here's where things stand right now" to inline into its prompt —
it should not have to load and recompute stats from the raw period YAML itself. This
spec covers only the brick that produces that snapshot: a `current_stats.md` file,
regenerated automatically whenever the current period's data changes. The periodic job,
prompt template, staleness warning, and LLM call are all out of scope here.

## Decision

On every change to the period that contains today's date, regenerate
`<periods_dir>/current_stats.md` — a single, fixed-name file, always overwritten in
place, reflecting whichever period is "current" by date at generation time. It lives in
the same directory as the period YAML files, so it rides along with the user's existing
git workflow for that folder.

The feature is gated by a Settings toggle, **default: enabled**. When disabled, the app
deletes any existing `current_stats.md` rather than leaving a stale file behind.

### Format: Markdown

Markdown was chosen over YAML/JSON because the file needs to satisfy both stated goals
at once — human-readable on its own, and directly inlineable into an LLM prompt with no
reformatting step. The file contains only facts and figures; it carries no AI
instructions or tone guidance (that belongs in the downstream prompt template).

### Content

```markdown
# Budget Stats — February 2026

## Meta
- Period: February 2026 (2026-02-01 → 2026-02-28)
- Today: 2026-02-25 (day 25 of 28, 4 days remaining)
- Generated: 2026-02-25 14:32
- Currency: EUR

## Pacing
- Time elapsed: 89% (25 / 28 days)
- Budget spent: 74% (135,610 / 183,610 total budget)
- Average daily spend so far: 6,957 / day
- Projected total at this rate: 194,796 (vs. budget 183,610)
- Free money remaining: -2,600
- Income: 152,500 planned / 171,324 actual

## Categories (sorted by budget heat, highest first)
| Category | Type | Daily Allow. | Budget | Spent | Remaining | Heat | Over? |
|---|---|---|---|---|---|---|---|
| 🧺 Home Essentials | Optional | no | 500 | 24,868 | -24,368 | 4973% | yes |
| 👨‍👩‍👧‍👦 Family | Optional | no | 5,000 | 11,800 | -6,800 | 236% | yes |
| ... | | | | | | | |

## Planned Expenses — Overdue & Upcoming (next 14 days)
| Category | Description | Amount | Due | Status |
|---|---|---|---|---|
| 💳 Loans | Mortgage | 40,158 | 2026-02-20 | overdue |
| 📞 Communications | Phone bill | 650 | 2026-02-27 | pending |

## Summary Totals
- Mandatory: 122,610 budget / 95,783 spent
- Optional: 61,000 budget / 39,827 spent
- Categories over budget: 6 of 17
```

Notes:

- All dates/times (`Today`, `Generated`, due dates) use local system time via
  `DateTime.now()`, matching every other date computation in this codebase — no UTC
  conversion.
- **Daily Allow.** reflects `Category.isDailyAllowance`; when true, that row also
  carries its daily-allowance-amount figure and, when available, the smart spending
  cadence derived from the 20% trimmed mean of past purchases (the same figures the
  category header shows), e.g. `yes (600/day left, or 1,400 every 3 days)`.
- **Average daily spend** and **projected total at this rate** are new derived metrics —
  simple arithmetic on top of existing `PeriodStats` fields (`totalSpent` / days
  elapsed, projected against `totalBudget`). No new data model needed.
- The overdue/upcoming table reuses the due-date resolution + overdue-detection logic
  already in `period_stats_provider.dart:133-162`, extracted into a small shared helper
  so the two call sites can't drift.
- A category with no planned expenses is simply omitted from that table; if none exist
  at all, the section prints "None."
- Categories are rendered in the same heat-descending order `periodStats` already sorts
  by, so the categories closest to (or over) budget lead the file.

## Architecture

### New components

- **`lib/src/logic/period_stats_markdown.dart`** — pure function
  `String formatCurrentPeriodStatsMarkdown(Period period, PeriodStats stats, DateTime endDate, DateTime now)`.
  No I/O; fully unit-testable.
- **Due-date resolution helper** — the `exp.dueDate.when(exact: ..., dayOfMonth: ...)`
  logic in `period_stats_provider.dart` is extracted into a shared helper (e.g. in
  `period_extensions.dart`) so both the existing `periodStats` provider and the new
  formatter use one implementation.
- **`lib/src/storage/period_stats_writer.dart`** — `writeStatsFile(directoryPath, markdown)`
  and `deleteStatsFile(directoryPath)`, mirroring `PeriodRepository`'s plain
  `File(...).writeAsString(...)` style.
- **`AiStatsSettingsService`** (new, `lib/src/storage/`) — persists a bool toggle via
  `shared_preferences`, default `true`. Same shape as `StorageSettingsService`.
- **`aiStatsSettingsProvider`** (new, `@riverpod` class) — mirrors
  `storageSettingsProvider`'s pattern, exposing the toggle plus a setter.
- **`currentPeriodStatsSyncProvider`** (new, `@riverpod FutureOr<void>`) — watches
  `periodStatsProvider`, `currentPeriodProvider` (for the `Period` and, via
  `allPeriodsProvider`, `effectiveEndDate`), and `aiStatsSettingsProvider`. On every
  recompute: if enabled and a current period exists, format and write the file; if
  disabled, delete it if present. try/catch around the write, swallowing failures
  silently — matching the existing convention in `PeriodNotifier._debouncedSave` /
  `CurrentPeriod._debouncedSave`, since a stats-file write failure shouldn't interrupt
  normal period editing.

### Why a reactive provider, not direct calls

Expense edits flow through `PeriodNotifier(periodId)` (any period), while period
creation/rollover flows through `CurrentPeriod.setPeriod`. Both already funnel into
`currentPeriodProvider` being invalidated. Rather than adding an explicit "write stats"
call at the end of each notifier's save path (two places today, more tomorrow),
`currentPeriodStatsSyncProvider` watches the already-existing `periodStatsProvider` —
which is itself always computed for whichever period is current by date — and reacts
automatically. This also delivers "always computed from today's period, regardless of
which period was actually edited" for free, since that's already `periodStatsProvider`'s
exact semantics. Any future mutation path automatically triggers regeneration without
needing to remember to wire it in.

The 500ms debounce already present in both notifiers' save paths means the file isn't
rewritten on every keystroke — only once per settled save-and-invalidate cycle.

### Activation

`app_shell.dart` adds `ref.watch(currentPeriodStatsSyncProvider)` (value discarded) at
app root, keeping the provider alive for the app's lifetime — the same mechanism used
for other always-on providers in this app.

### Settings UI

A new toggle row in `settings_view.dart`, in a new section (e.g. "AI Insights Data"),
following the existing `Container` / `_SectionHeader` visual pattern already used on
that screen.

## Testing

1. **`test/period_stats_markdown_test.dart`** (new) — given a crafted `Period` /
   `PeriodStats`, assert the rendered Markdown's meta line, pacing numbers, category
   table rows (heat-sorted), and overdue/upcoming rows, including the "None" case.
2. **Due-date helper extraction** — `period_stats_provider_test.dart`'s existing
   overdue/pending assertions must keep passing unchanged after the extraction.
3. **`test/current_period_stats_sync_provider_test.dart`** (new, temp-directory based
   like other storage tests) — file is written when enabled + a current period exists;
   file is deleted when the toggle flips off; write is skipped when there's no current
   period.
4. **`AiStatsSettingsService` test** (new) — mirrors `storage_settings_service_test.dart`
   (default `true`, persists across reads).

No widget test is planned for the new Settings toggle row — no widget tests exist for
other `settings_view` rows either.

## Out of scope

- The periodic job that reads `current_stats.md`, judges staleness, builds the LLM
  prompt, and surfaces insights to the user.
- The prompt template itself and any LLM/provider integration.
- Any change to the underlying period YAML storage format.
- Historical/previous-period comparisons (e.g. "spending 12% higher than last month") —
  a reasonable future enhancement, but out of scope for this snapshot brick.
