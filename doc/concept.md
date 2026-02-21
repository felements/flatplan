
Need to create a technical specification for the desktop app. Tech stack - flutter with desktop target (windows, linux, macos) (developing on windows) + local file storage (sorted yaml to avoid lines drift in git). Consider future move to the mobile and web versions.
The specification should be suitable for the implementation with AI assistance.
Need to decompose the app into stages to minimize the context overflow for the AI. Put every stage into a separate file.

Need to think up the storage structure (models); UI pages and the list of components for every page.




## Motivation


- As simple as possible, no excess analytics, account tracking, etc. 

- "Exact accounts tracking and keeping spending merchants" - bullshit and obsolete things for small budgets - you always know where you've spent your free $200. So keeping only amounts and optional comments

- Highlevel concept - the user will have a set of categories; every category will have a limit and a list of planned expenses for every category (optional). So the spendings are written in the category in two ways - as a free spending (consuming the limit); or as a planned expense (also consuming the limit) by checking and completing the planned record. No need to keep track of accounts, only total amount of the category is needed.


## Key features


- ~~Self-hosted, no sensitive data in cloud~~   Making Desktop app instead + JSON/YAML file in git repository

- Customizable period length + start date. Period can start from e.g. 7th of the month to match the day of the salary payment. And it is not the strict rule, next one could start from 9th of the month - in case of the salary delay.

- Planned expenses in a category should have a description per every item, just a sum is not informative.

- Planned expense could have a due date (day of month; day of week or the exact date) (e.g. recurrent installment payments)

- The user could prepare plans plans for the next 2-3 periods (period files would be created but will start in fact only on the day of the period start)

- Every period file should have a name - a name of month and a year by default, but could be changed by the user.

- Next period file should be created based on the one of the previous period files or on the template file.

- Local file storage (yaml) - one period = one file. Start the period - means to create a new file based on the template or one of the previous periods, review planned and mandatory expenses, then start to fill in the fact expenses. 

- Mandatory income\expenses + one-time only for this period (not copying to the next period).

- Categories - can have the list of exact-amount spendings and/or a category limit. As an option - daily allowance counter (is-enabled flag).

- Base currency (configurable per period)
- Multicurrency input, grab conversion rate from the internet (vnext)
- all categories should be splitted into two scopes - mandatory and optionall to clearly upderstand the free budget amount. If some payments have same category by the meaning, but different mandatory status - the user will create two categories with the same name and different mandatory status.
- End of the period is computed based on the start of the next one (if already exists) or based on the same day of month of the next month.
- need to keep last modification time for the period, to get to know from what moment to continue the expenses tracking.
- Need to keep the order of the tracked expenses.
- the user can also freely delete any of the tracked expenses in the row or uncheck the planned expense


## Computed stats


- Totals - Planned income to planned expenses
- Totals - Fact income to planned expenses
- Totals - Fact income to fact expenses

- In category - per day remaining spendings until the end of the period (displayed for current period - computed for current day; and for future periods - computed as it would be the first day of the period).
- In category - Heat indicator of remaining spendings in category (turns red on overspending)

- Total spendings - remaining sum over all categories (sum of "positive" remaining amounts in categories - mandatory + optional)
- Total spendings - out of budget over all categories (sum of "negative" remaining amount in categories - mandatory + optional)




## Storage


- A period template file - list of categories + expenses, category mandatory status

- Period data - one file per period. Created based on a template or another period (in this case keeping only planned expenses, dropping all fact expenses) .




