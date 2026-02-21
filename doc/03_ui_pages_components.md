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

## 4. Settings/Template Manager Page
- Manage the core `template.yaml`.
- Define the root storage directory path.
