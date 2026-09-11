# Category allowance insights: pace and basket

**Date:** 2026-09-11
**Status:** Approved

> Design figures in this document are synthetic. The rules below were validated against
> a private budget dataset that is not part of this repository; only ratios and
> distribution shapes from that validation are reported here.

## Problem

Daily-allowance categories currently show two figures: the plain `remaining / daysLeft`
division, and a "spend X every N days" suggestion derived from a 20% trimmed mean of the
category's own fact expenses.

The second figure does not work, for three separate reasons.

**It measures line items, not baskets.** A single shopping trip is entered as many
separate fact expenses — one per receipt line, sometimes several stores in one sitting.
The trimmed mean of those rows is the size of a typical *row*, which is far smaller than
a basket and has no meaning to the user.

**It degenerates.** Once the typical row is small enough that more of them are
affordable than there are days remaining, `round(daysLeft / affordable)` collapses to 1.
The tile then reads "X / day left or spend Y every 1 days" — the same rate stated twice,
with the second statement less accurate than the first because of the rounding. It would
round to 0 if rows got smaller still.

**Its history window keys on the wrong field.** `FactExpense.timestamp` is set to
`DateTime.now()` at every creation site and there is no date control in the UI, so it
records when a row was *typed in*, not when the money was spent. Receipts are entered in
bulk, days or weeks late. The 30-day sliding window added in #14 therefore filters on
data-entry recency. Validation data showed periods whose expenses were entered on as few
as two distinct days, none of them inside the period's own date range.

## Decision

Replace the single broken figure with two insights that answer two different questions.

**Pace** answers "am I on track?" and is automatic for every daily-allowance category.
**Basket** answers "what can I safely spend in the shop right now?" and is opt-in per
category, because it needs one piece of human knowledge the data cannot supply.

Both derive their history from **period membership** — which period file an expense
lives in — never from `timestamp`. That signal is reliable and needs no schema change.

### Insight A — Pace

```
safeDaily   = remaining / daysLeft
recentRate  = previous period's category total / that period's length in days
projection  = spentThisPeriod + daysLeft x recentRate
```

`projection` is compared against the category's effective limit. When it exceeds the
limit, the overshoot is surfaced and the UI marks it as a warning.

The previous period alone is the basis, not a multi-period average: spending rates were
observed to trend steadily rather than oscillate, so the most recent complete period
tracks the current trajectory best.

Pace is suppressed entirely when the period has already ended, per the existing rule in
`paceForCategory` — a closed period has no days left to pace anything over.

### Insight B — Basket

Enabled by setting a big-purchase threshold on the category. Expenses below it are
"small" (incidental, snack-type); at or above it they are "baskets".

Statistics come from the **last 3 complete periods**, excluding the current one, taking
the **worst** value of each rather than the mean:

```
snackShare  = max  over periods of  sum(small) / total
tripSpacing = min  over periods of  periodDays / count(large)
usualBasket = median over periods of  median(large)     // displayed as context only
```

The advice itself:

```
snackReserve = max(0, snackShare x effectiveLimit - smallSpentThisPeriod)
basketBudget = remaining - snackReserve
tripsLeft    = daysLeft / tripSpacing
safeBasket   = basketBudget / tripsLeft
```

Worked example with synthetic figures — limit 10,000, 8,000 remaining over 20 days,
500 already spent on small items, a measured 30% snack share and a basket every 2 days:

```
snackReserve = max(0, 0.30 x 10,000 - 500)  = 2,500
basketBudget = 8,000 - 2,500                 = 5,500
tripsLeft    = 20 / 2                        = 10
safeBasket   = 5,500 / 10                    =   550
```

Returns null when fewer than 2 complete prior periods exist, or when a period in the
window contains no basket-sized expense at all (`count(large) == 0` would divide by
zero). The category then shows Pace alone.

#### Why the reserve is taken against the limit

Reserving `snackShare x remaining` would recompute the reserve against a shrinking base
every day, so overspending on small items would quietly hand budget back to baskets.
Anchoring to `effectiveLimit` and subtracting what small items have already consumed
makes the reserve self-correcting: once small spending exhausts its share, the reserve
floors at zero and every further small purchase tightens `safeBasket` directly, because
`remaining` has fallen.

#### Why conservative rather than averaged

The figure's purpose is to be safe to act on before walking into a shop, so it should
fail toward "spend less". In validation the tightest of the three trip spacings was also
the most recent, i.e. trip frequency was rising; a mean would have lagged that trend and
issued a per-basket figure larger than the user could afford. Taking the worst of each
statistic costs roughly a quarter of the headroom a mean would report.

#### Why the threshold is human-set

There is no clean valley in the amount distribution to discover — validation data was
close to continuous in log space with only a weak dip. A threshold sweep that selected
for maximum stability chose a degenerate split at which nearly every expense counted as
a basket: the snack share became trivially small and stable, and trip spacing collapsed
to about one day. That is the same failure the current feature already exhibits,
rediscovered by a different route. Any automatic selection optimising for stability
walks into it.

The user, by contrast, knows what the boundary means in their own life. So the category
editor leaves the field empty when no threshold is set, offering a suggestion computed
from history as helper text; nothing is written unless the user types a value. Sensitivity
around a reasonable value is mild and monotone, so an imprecise threshold degrades
gracefully rather than cliff-edging.

#### Why 3 periods

Validation showed the snack share drifting roughly threefold across eight periods as
habits changed, then settling. Standard deviation across all history was about three
times that of the trailing three periods — the long window was too noisy to reserve
against, while the short one was stable. Three is fixed, not configurable; two is the
minimum for the insight to appear at all.

## Data model

One new field on `Category`:

```dart
double? bigPurchaseThreshold,
```

Non-null enables Insight B and carries its threshold. No separate boolean — absence is
the off state. Serialises as `big_purchase_threshold` under the project's global
`snake_case` rule; existing period files without the key deserialise to null and keep
today's behaviour.

## Code structure

Per the rule recorded in `AGENTS.md`, all derived figures live in `lib/src/logic/` and
the views stay thin.

- **`lib/src/logic/basket_insight.dart`** (new) — `BasketStats` (snack share, trip
  spacing, usual basket, periods used) and `BasketAdvice` (reserve, basket budget, trips
  left, safe basket). Pure functions over `List<Period>`; no provider or widget imports.
- **`lib/src/logic/allowance_pace.dart`** — `paceSamples` and `estimateAllowancePace`
  are deleted along with their tests; the trimmed-mean approach cannot be repaired.
  `paceForCategory` keeps its signature and returns the new pace figures.
- **`lib/src/logic/period_stats.dart`** — `CategoryStats` gains fields for both
  insights. Because all three call sites already funnel through `categoryStatsFor`, no
  view computes any of this.

`BasketStats` is separated from `BasketAdvice` deliberately: the former is a property of
the user's history and is what the category editor needs to seed its threshold
suggestion; the latter is a property of the current period. They are computed and tested
independently.

## UI

**Category tile** — a second line below the existing one, in the warning colour when the
pace projection exceeds the limit:

Continuing the synthetic figures from the worked example above:

```
Groceries                                    2,000 / 10,000
  550 safe per shop  ·  400 / day left
  averaging 520/day — heading 2,400 over
  ▁▁▁▁▁▁▁▁▁▁▁▁
```

The safe-per-shop figure leads because it is the one the user acts on. When Insight B is
off or unavailable, the first line falls back to the daily figure alone.

**Category detail view** — the full breakdown: reserve, basket budget, trips remaining,
usual basket for comparison, and which periods the statistics were drawn from, so the
number can be audited rather than trusted blindly.

**Category editor** — a big-purchase threshold field beside the daily-allowance toggle,
left empty when no threshold is set, with a suggestion derived from the category's history
shown as helper text; nothing is saved unless the user types a value.

All three follow `doc/08_design_guidelines.md`.

## Testing

- **`basket_insight.dart`** — conservative selection picks the worst of each statistic;
  the reserve floors at zero once small spending exhausts its share; null below two
  complete periods; null when a window period holds no basket-sized expense; threshold
  boundary is inclusive at the low end of "large".
- **`allowance_pace.dart`** — projection arithmetic; the ended-period suppression rule
  survives the rewrite.
- **Provider** — a multi-period fixture asserting both insights reach `CategoryStats`.
- **Widget** — the tile renders both lines, and the warning colour appears only when the
  projection exceeds the limit.

Tests use synthetic fixtures. No real budget data enters the repository.

## Out of scope

**A real spend date on `FactExpense` — rejected, not deferred.** The timestamp problem is
worked around here by using period membership, which is sufficient for both insights. A
user-editable spend date would fix it at the source and would make shopping-trip grouping
possible, but it is ruled out on product grounds: entries are routinely filled in days
late, so defaulting to today is wrong, and a manual date field adds a decision to every
single entry. That contradicts the app's core principle of keeping accounting frictionless
— the reason to reach for it is that recording a purchase takes seconds. Do not re-propose
it; any feature needing real spend dates must find another route or be dropped.

**Splitting the category in two.** Modelling snacks and groceries as separate categories
was tried and rejected by the user: the split is not predictable in advance, since
whether a given meal is cooked at home or eaten out is decided on the day. Insight B
exists precisely to recover that separation statistically after the fact.
