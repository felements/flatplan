# Stats page — design

Date: 2026-11-10 · Status: approved 2026-11-10

## Why

The user is trying to bring the household's grocery spending down and wants
to see whether it is actually falling from one period to the next, and
whether some months always run higher. The same question applies to a tag
(how much went on `#renovation` each period) and to income. Today the app
only shows one period at a time, so none of this is visible.

## What it is

A new **Stats** page. On the left, a list of everything that can be plotted
(totals, expense categories, income categories, tags), each with a checkbox.
On the right, a line graph: one point per period along the X axis, the
amount on the Y axis, one line per ticked subject. Above the graph, a period
range picker. Approved mockups: layout "B" and limit drawing "A" (described
below; screenshots are not kept in the repo).

## Goals

- Show each subject's **raw per-period total**, period by period.
- Subjects: **All** (the default), any **category** (expense or income), any
  **tag**. Several can be ticked at once, each its own line.
- Range: **all periods** (the default) or **from one month to another**.
- For a ticked category, show **its limit in each period** as a stepped line,
  because limits change from period to period.

## Non-goals

- **No normalising by period length.** The user rejected per-day figures: a
  period's limit is set for the whole period and has to be kept, so the
  whole-period sum is the figure that matters, even when periods differ in
  length.
- Planned payments are not counted; only recorded (fact) payments are.
- No currency conversion. Amounts are summed as recorded, like the dashboard's
  Top tags card. Multi-currency is a separate roadmap item.
- No editing from this page, no export, no saved views.

## Anti-goals

- Figures that disagree with the dashboard for the same period. A period's
  "All" spent and earned must equal that period's dashboard figures, and a
  category's value must equal its category tile's spent figure (the sum of
  same-key categories, when a period has duplicates).
- Extra concepts or settings beyond what is described here. The user has
  asked more than once to keep things simple.

## Definitions (confirmed by the user)

**Period.** The app's budget unit: starts on the day the user chose, ends the
day before the next period starts (see `doc/01_storage_models.md`). One point
on the X axis is one period, in start-date order. The set of periods is the
one the app already loads (`allPeriodsProvider`), the same the sidebar lists.

**Range.** "All periods", or a from-month and a to-month (inclusive). A period
belongs to the range by the month its `startDate` falls in.

**All.** Two lines: **spent**, the period's recorded spending across every
expense category (mandatory and optional) — `PeriodStats.totalSpent`; and
**earned**, the period's recorded income — `PeriodStats.totalFactIncome`.

**Category.** Matched across periods **by name** (trimmed, case-insensitive),
because rollover regenerates category ids — the same rule as
`priorCategoryHistory` in `logic/period_history.dart` — **within its kind**:
an expense category (mandatory or optional) and an income category with the
same name are two separate subjects (see my call 2). Value = the sum of
recorded payments in that category in the period.
- Period where the category **did not exist**: a **gap** in the line.
- Period where it existed but had no payments: **0**.

**Tag.** Value = the sum of recorded payments in **expense** categories whose
comment carries the tag (`splitTags` in `logic/payment_tags.dart`). A payment
with several tags counts in full under each — the same rule as the Top tags
card. Tags on income payments are not counted. A period with no such payment
shows **0** (a tag has no "did not exist" state).

**Limit line** (categories only; not for All or tags). Per period, the
category's **effective limit** — `Category.effectiveLimit` (the limit, or the
planned total when that is larger), i.e. the figure that period's dashboard
tile compared against. For an income category this is its planned income.
Drawn as a **faint dashed stepped line in the category's colour**, holding
flat across each period's slot and stepping where the limit changed. A period
where the category is absent or its effective limit is 0 has no limit drawn.

**Current period.** Included, although its total is still growing. The
stretch of each line leading into it is dashed and its point is hollow, so
the dip reads as "not finished", not as a saving.

## The page (decided with the user)

- **Navigation:** a **Stats** item in the sidebar, directly under **Today**
  (above "+ Next period").
- **Subject list** (left column, ~170–220 px, card style): a search box, then
  groups **Totals** (All), **Expenses**, **Income**, **Tags**. Each row has a
  checkbox; a ticked row shows its line colour as a dot.
- **Default:** All ticked. Ticking any other subject unticks All; unticking the
  last ticked subject ticks All again. (Otherwise a small category is drawn
  squashed flat beneath the period totals.)
- **Range picker:** a button reading "All periods" (or the chosen range) at
  the top right; opens a small panel with "All periods" / "From – to" and two
  month fields.
- **Graph** (right, card style, 16 px radius per `doc/08_design_guidelines.md`):
  - X labels: the period's start month as `MMM yy` (same as the sidebar).
  - Y axis from 0; plain numbers with no currency symbol, formatted like the
    Top tags card (`NumberFormat.decimalPatternDigits(decimalDigits: 0)`).
    All lines share one axis.
  - Hovering a period shows a tooltip: the period's full name, then each
    line's value, with the category's limit under its value. Lines with a gap
    at that period are left out of the tooltip.

## My calls (not discussed with the user — check these)

1. **Lists and ordering.** Expenses and Income list every category name found
   in any loaded period; Tags list every tag found in any expense payment in
   any loaded period. Each group is sorted alphabetically. The list does not
   shrink when a range is picked. The search box filters all groups by
   case-insensitive substring.
2. **What makes one category subject.** The key is the name (trimmed,
   case-insensitive) **plus its kind**, expense or income. Mandatory and
   optional both count as expense, so a category switched between them keeps
   one history; an expense "Other" and an income "Other" are two subjects, so
   no line ever mixes spending with income. A subject is shown with its
   spelling in the most recent period that has it. If one period holds two
   categories with the same key (the category dialog does not stop duplicate
   names), their payments and effective limits are added together.
3. **Periods that start after today** (a next period created early) are left
   out: they hold no payments yet and would read as a drop to 0.
4. **Colours.** All's lines: spent in teal (`colorScheme.secondary`, the app's
   spent colour), earned in gold (`colorScheme.primary`). Other subjects take
   colours from a fixed palette of about eight, in the order they were
   ticked; the palette must read on both dark and light themes. Coral is kept
   out of the palette because it means "over budget" elsewhere.
5. **Selection is kept for the session** (leaving the page and coming back
   keeps the ticks and range) but is not saved to disk. Making Stats its own
   `StatefulShellBranch` gives this for free.
6. **Chart library:** `fl_chart` (MIT), a new dependency. It covers multiple
   series, gaps (null spots), stepped lines and tooltips. A hand-written
   `CustomPainter` is the fallback if it gets in the way.
7. **Empty states.** No periods at all: the page shows a short message
   instead of the graph. Ticked subjects with no data in the range: the graph
   frame stays, with a one-line note.

## Constraints

- All series maths lives in `lib/src/logic/` (AGENTS.md rule 4), provider-free
  and unit-tested; the view only maps series to chart widgets. A logic test
  must pin "All" and category values to what `periodStatsFor` /
  `categoryStatsFor` report for the same period.
- Follow `doc/08_design_guidelines.md` (cards, typography, sidebar item style,
  dark and light themes).
- Delivery: branch `feat/stats-page`, built on `main` (which includes the
  payment tags from PR #29). Commit locally as work
  goes; **push and open the PR only when the whole feature is finished** and
  verified (`flutter analyze` clean, full `flutter test` green). The PR adds a
  CHANGELOG `[Unreleased]` → Added entry, a Stats page section in
  `doc/03_ui_pages_components.md`, the sidebar change in
  `doc/08_design_guidelines.md`, and the new view/logic files in AGENTS.md's
  Key Architecture list.

## Left to the builder

- Exact widths, spacing, icon for the sidebar item, the palette's colours.
- How the series are computed (one pass over periods, caching, provider
  shape), as long as the figures match the dashboard.
- Narrow-window behaviour (the app is desktop today; mobile is planned): a
  reasonable fallback such as the list above the graph is fine.
- Tooltip and range-panel widget choices.

## Addendum: the payments behind a dot (agreed 2026-11-10)

The graph shows how much was spent but not what the sum is made of. Clicking
a dot lists the recorded payments behind its figure in a card under the
graph, so a spike (e.g. October's `#tws`) can be read payment by payment.

- A dot lists what its figure adds up: All's spent dot every expense
  payment, its earned dot every income payment, a category's dot the
  payments of every same-named category of its kind, a tag's dot the expense
  payments carrying the tag (each once). The listed total always equals the
  dot's value. Limit lines are not clickable.
- Rows: day, comment with tag chips, category (left out on a category's own
  line), amount in the period's currency; oldest first. Read-only.
- The picked dot is ringed; another dot switches the list; the same dot
  again or ✕ closes it, as does unticking the subject or picking a range that
  leaves the period out. The current period's hollow dot can be picked too.
- My call: a click anywhere in a period's column picks the dot there nearest
  the pointer.
- Asked alongside: the legend shows each line's total over the periods on the
  chart (gaps count as nothing; the period in progress counts as it stands).
