# Design Guidelines

Visual identity reference for FlatPlan's UI. All new screens and components **must** follow these guidelines to keep the app cohesive.

## Theme Architecture

The centralized theme lives in `lib/src/app_theme.dart` and exposes `AppTheme.darkTheme` (primary) and `AppTheme.lightTheme`. Dark mode is the default (`ThemeMode.dark` in `main.dart`). Google Fonts **Outfit** is the app-wide typeface.

## Color Palette

| Token | Hex | Usage |
|---|---|---|
| Scaffold | `#121218` | Page / window background |
| Surface | `#1A1A24` | Sidebar, modal overlays |
| Surface Container | `#1E1E2E` | Cards, panels, input fills |
| Surface Container High | `#252532` | Hover states, secondary fills |
| **Primary (gold)** | `#D4A84B` | CTA buttons, selected nav, progress bars, accent icons |
| Primary light | `#E5BF6A` | On-primary-container text |
| **Secondary (teal)** | `#5A8F7B` | Spent-amount indicators, secondary badges |
| **Error (coral)** | `#E07A5F` | Over-budget states, destructive actions |
| On-surface | `#E8E6F0` | Primary text |
| On-surface-variant | `#9D9BAA` | Labels, muted text, secondary icons |
| Outline | `#3A3A4A` | Visible borders, focused input stroke |
| Outline variant | `#2A2A38` | Subtle borders, dividers |

### Card Tint Backgrounds

Used on `SummaryCard` for visual differentiation:

| Name | Hex | Applied to |
|---|---|---|
| `cardGold` | `#3D351F` | Total Budget card |
| `cardTeal` | `#1D3129` | Total Spent card |
| `cardGreen` | `#1F3325` | Remaining card |
| `cardCoral` | `#3D2420` | Error / over-budget card |

## Typography

- **Family**: Outfit (via `google_fonts` package)
- **Hero numbers** (amounts): `headlineMedium`, bold
- **Section titles**: `titleLarge`, bold, with a leading accent icon
- **Body text / labels**: `bodyMedium`, regular weight, `onSurfaceVariant` color
- **Small captions**: `bodySmall`, muted

## Component Standards

### Cards / Containers
- Border radius: **16 px**
- Background: `surfaceContainerLow` (or a tint from the card palette)
- Border: 0.5 px `outlineVariant` at 30-40 % opacity
- Shadow: multi-layer (`black @30 % / 12 blur / 4 offset` + `black @15 % / 4 blur / 1 offset`)

### Buttons (Elevated)
- Background: gold `#D4A84B`, text: dark `#1A1400`
- Border radius: **12 px**
- Padding: 24 h × 14 v
- Elevation: 0 (flat)

### Inputs
- Filled, `surfaceContainerHigh` fill
- Border radius: **12 px**
- Focused border: gold 1.5 px

### Sidebar Navigation (`AppShell`)
- Width: **220 px**, full-height dark surface panel
- Top: FlatPlan branding (wallet icon in rounded badge + bold title)
- Items: icon + label in a `Row`, 12 px rounded `Material` highlight (gold @ 12 % opacity when selected)
- Hover: gold @ 6 % opacity

### Category Tiles
- Animated hover background transition (180 ms ease-out)
- Heat progress bar: 6 px height, 6 px border radius
- Colors: gold (normal) → amber (> 85 %) → coral (over-budget)

### Section Headers
- Pattern: `Icon` (18 px, primary color) + `SizedBox(width: 8)` + `Text` (titleLarge, bold)

## Spacing Conventions

| Context | Value |
|---|---|
| Page padding (horizontal) | 32 px |
| Page padding (vertical) | 8–20 px |
| Between summary cards | 16 px |
| Between category tiles | 8 px (4 px padding each side) |
| Section gap | 32–36 px |
| Sidebar item horizontal padding | 12 px |
| Card internal padding | 16–20 px |

## Accessibility

- Text contrast ratio ≥ 4.5 : 1 on all surface backgrounds (verified for `onSurface #E8E6F0` on `#121218` scaffold and `#1E1E2E` cards)
- All interactive elements have `InkWell` / `Material` wrappers for keyboard focus and hover feedback
- Icon-only elements are always paired with text labels (sidebar, section headers)
