# Dragon Shield UI/UX Design Guide

Version: 1.0  
Date: July 2025  
Author: Dragon Shield Design Team  

---

## ✨ Design Philosophy

Dragon Shield follows a **ZEN-minimalist** approach combined with Apple-native UX best practices:

- **Clarity over clutter**: Only display what matters for the current task.
- **Keyboard-first design**: Full navigation and functionality via keyboard.
- **Purposeful use of color and visual elements**: Colors, icons, and charts serve clear analytical or navigational roles.
- **Consistency and familiarity**: Similar elements behave the same across views.

---

## 🖊️ Layout & Structure

### Navigation Sidebar (Left)
- Width: ~220px
- Background: `#1B1D23` in dark mode / light neutral in light mode
- Font: SF Pro / 15 pt / Medium
- Sections: Context-aware grouping (e.g., Dashboard, Portfolio, Transactions, Import, Settings)
- Current selection: Highlighted with pill background + bold text

### Top Navigation (Optional)
- Avoid unless needed for sub-context (e.g., sub-tabs inside a detailed view)

### Main Content Area
- Adaptive layout for charts, forms, and lists
- Minimum padding: 24px around core content
- Use cards (`8px` corner radius) to visually group functional blocks

---

## 📊 Visual Language

### Color Palette
| Purpose              | Color (Light Mode) | Color (Dark Mode) |
|----------------------|--------------------|-------------------|
| Primary Accent       | #2A7DE1             | #4C8FE2           |
| Success (positive)   | #1E8E3E             | #36C26D           |
| Warning              | #E0A800             | #FFD666           |
| Error (negative)     | #D32F2F             | #FF6B6B           |
| Background           | #FFFFFF             | #121212           |
| Surface (cards)      | #F8F9FA             | #1F1F1F           |
| Text (primary)       | #212121             | #EAEAEA           |
| Text (secondary)     | #666666             | #A0A0A0           |

### Typography
- Font Family: SF Pro (Apple Standard)
- Sizes:
  - Title: 22–28 pt
  - Section Heading: 18 pt / Semibold
  - Body: 14–16 pt
  - Labels / Meta: 12 pt / Regular

---

## 👀 Visual Components & Behavior

### Charts
- Use Apple Charts API with smoothed curves for performance graphs
- Pie & bar charts for allocations
- Data labels should not clutter the view; show on hover or tap

### Buttons
| Type         | Style                                  | Usage                  |
|--------------|-----------------------------------------|------------------------|
| Primary      | Filled, accent color                    | Add, Confirm           |
| Secondary    | Bordered or subtle background fill      | Edit, Cancel           |
| Tertiary     | Text-only                               | Optional actions       |

### Inputs
- Rounded corners, light border, inline label when possible
- Use dropdown selectors for Date, Asset, Type, etc.
- Bulk actions (Import, Export) always bottom-aligned

---

## ⚖️ Functional Modules

### 1. Dashboard
- Tile layout (2x2 grid)
- Key tiles:
  - Allocation vs. Target (pie)
  - Asset Allocation (horizontal bars)
  - Top 5–8 Positions (text + color-coded change)
  - Alerts & Actions (list style)
- Use animation sparingly (e.g., data loading, tooltip hover)

#### Asset Allocation Panel
- **Card container**: 360×auto px with 12 px corner radius and 20 px padding. Background `#FFFFFF` / `#1C1C1E` in dark mode.
- **Title**: “Asset Allocation” in SF Pro Semibold 17 pt, `#1C1C1E` / `#EBEBF5`.
- **Row layout**: 32 px height with 8 px between rows. Grid columns 100 px label, flexible bar track, 40 px value label.
- **Label text**: SF Pro Regular 15 pt, `#3C3C4399` / `#EBEBF5CC`; truncate after 15 chars with tooltip.
- **Bar track**: 8 px high, 4 px radius, `#D1D1D6` / `#3A3A3C` with filled bar `#0A84FF` / `#64D2FF`. On hover, height grows to 10 px with subtle shadow.
- **Percentage label**: SF Pro Regular 13 pt, `#1C1C1E` / `#EBEBF5` showing e.g., `23%`. Hover tooltip reveals full precision.
- **Legend & interaction**: Optional legend (actual vs target) in top-right. Clicking a row drills into details. Title hover shows sort toggle.

### 2. Portfolio Detail
- Context panel (left) with instrument selection
- Strategy note field: Freeform markdown-style block
- Price chart: Time-based with date ticks and hover tooltips
- Key metrics: Position size, gain/loss, performance

### 3. Transaction Log
- Filters: Date / Asset / Type
- Table view with consistent formatting
- Click on row: opens detail panel (right side)
- Attachments: File icon + filename with checkbox
- Inline edit modal: reuse for small updates

### 4. Import Workflow
- Drag & drop zone prominent and centered
- Table shows parsed preview below
- Right side: Progress bar + validation summary
- Highlight errors (red) and duplicates (greyed with icon)

### 5. Command Palette
- Full-screen modal with dark blur background
- Search first interaction (⌘K or custom shortcut)
- Grouped sections: Actions, Portfolio, Report
- Action icons optional

### 6. Dark Mode
- Fully supported using system preference
- Consistent contrasts, accessible color ratios
- Charts and highlights adjust brightness accordingly

---

## ✉️ Copy & Tone
- Tone: Professional but human
- Numbers: Always use commas (e.g., $31,156.00), % always with one decimal if over 10% (e.g., +7.0%)
- Placeholder copy: Must be realistic and error-free
- Avoid lorem ipsum
- Spellcheck for typos (noted in early mocks: "Perchasa", "Chyple")

---

## 🔍 Accessibility & UX
- Ensure contrast > 4.5:1 minimum
- Keyboard navigation: All buttons, fields, and toggles reachable
- Animations: Max 300ms, disable if prefers-reduced-motion
- Tooltip on hover for abbreviations and icons

---

## 🔮 Assets & Icons
- Iconography: Use SF Symbols if native, custom SVG otherwise
- Images from screenshots should be referenced like:
  `/design/images/01_dashboard_main.png`
  `/design/images/02_portfolio_management.png`
  etc.

> Let us know if we should include screenshots directly within the document for clarity.

---

## Database Management & Backups
- Use **Backup Database** and **Restore Database** for full file copies.
- **Backup Reference** exports only the core reference tables.
- Use **Restore Reference** to load such a backup without affecting user data.

---

## 👥 Contributor Guide
- All contributors must follow this guide when implementing new views
- Before submitting PRs, verify alignment with typography, spacing, color usage, and interaction models
- Flag UX uncertainties in the pull request comments for review

---

## 🌐 File Organization (in GitHub)
- `/design/DragonShield_UI_Guide.md`
- `/design/images/*.png`
- `/design/components/*.sketch` or `.fig` (optional)

---

End of Guide

