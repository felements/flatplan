# Stage 3: UI Pages & Components

## General Guidelines
- **Responsive Layout**: Utilize the space of large desktop panels (e.g., a two-panel / master-detail layout) and adapt gracefully for small laptops by falling back to a classic navigation approach for subscreens.
- **Native Look & Feel**: Utilize standard approaches regarding general components to feel native on Windows, GNOME, and macOS frameworks.

## Overall Desktop Layout
As a desktop application, the app should use a spacious layout (e.g., Navigation Rail on the left or a standard Top App Bar, and a Master-Detail or expansive grid layout for the main content).

## 1. Dashboard Page (Home)
The primary view acting as the control center for the active period.

### Components
- **Header Selection**: 
  - Dropdown or Prev/Next arrows to switch the active period.
  - "Create Next Period" button (visible if the chronological next period doesn't exist).
- **Summary CardsRow (Computed Stats)**:
  - *Planned Income vs Planned Expenses*
  - *Fact Income vs Planned Expenses* (Pacing)
  - *Total Remaining*: Sum of all positive remaining categories.
  - *Total Over-budget*: Sum of all negative remaining categories.
- **Category Lists (Mandatory & Optional scopes)**:
  - Two distinct sections or columns separating `isMandatory=true` and `isMandatory=false`.
  - **Category ListTile**:
    - Displays: Category Name, Spent vs Limit, and Daily Allowance Remaining (if `isDailyAllowance` is true).
    - **Heat Indicator**: A linear progress bar that turns Red if `Spent > Limit`.
    - Tapping opens the **Category Detail Page**.

## 2. Category Detail Page
A focused view for managing a specific category's expenses in the current period.

### Components
- **Top Bar**: Category Name, Total Limit, Total Spent, Remaining. Back button to Dashboard.
- **Planned Expenses Section**:
  - List of `PlannedExpense` items.
  - Displays: Description, Amount, Due Date.
  - Interaction: Checkbox to toggle `isCompleted`. Unchecking it removes the virtual fact (handled by core logic).
  - Interaction: Swipe or click to edit/delete.
- **Fact Expenses Section**:
  - List of `FactExpense` items, ordered chronologically.
  - Displays: Amount, Optional Comment/Merchant, Time of entry, "One-Time" badge.
  - Interaction: Tap to edit, swipe/hover to delete.
- **Quick Action FAB (Floating Action Button)** / Input Row:
  - Always-visible row at the bottom to quickly type amount + comment and hit Enter to add a `FactExpense`.
  - Checkbox toggle for "One-time only (do not copy to next period)".

## 3. Period Initialization Dialog/Page
Triggered when starting a new period.

### Components
- **Source Selector**: "Based on Template" or "Based on [Previous Month]".
- **Date Configurator**: Select `startDate` (e.g., 7th of the month). The `endDate` is auto-calculated.
- **Base Currency Selector**.
- **Review Step**: Shows the list of categories and planned expenses to be carried over. Allows quick adjustments before generating the YAML file.

## 4. Settings Page
- Vault card: the open vault's name and location, an access-error banner when it cannot be opened, the list of unreadable period files, and a "Manage vaults" button.
- AI stats toggle, active tracking instance (period creation and rollover), and the About section.

## 5. Vault Switcher (sidebar footer)
- Sits above the Settings item: vault name with an up/down chevron; for a remote vault a one-line sync status ("Synced 2 min ago", "3 changes pending", "Offline", "Sync failed"); "Needs attention" when the vault cannot be opened.
- Tapping opens a menu listing every vault (check on the current one), then "Manage vaults…".

## 6. Vault Management (`/settings/vaults`)
- List: one card per vault with name, location line, "Current" and "Needs attention" chips, sync status and "Sync now" for an open remote vault, and an overflow menu with Edit and Remove. Removing asks for confirmation and never deletes user files; the last vault cannot be removed.
- Form (`/settings/vaults/new`, `/settings/vaults/:id/edit`): a kind chooser (only "Local folder" today; each remote provider adds one descriptor and one form), then the kind's form. The local form takes a name and, on desktop, an optional folder; without a folder the vault is stored inside the app, which is the only option on mobile.

## 7. Vault Unavailable View (dashboard)
- Shown instead of the dashboard when the selected vault cannot be opened: the reason and an "Open vault settings" button. Other vaults stay reachable from the switcher.
