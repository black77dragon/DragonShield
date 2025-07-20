# Data Import / Export Screen

This document defines the Data Import / Export view, including the Statement Loading Log.

## Overall Container
- **Layout**: Full-width card with light gray background (`#F9FAFB`)
- **Border**: 1 px solid `#E0E0E0`, rounded corners (`8 px`)
- **Padding**: 24 px
- **Margin**: 32 px from the top bar

## Section A – Header
- **Title**: `Data Import / Export` in 24 pt bold using the accent color (`#1A73E8`)
- **Subtitle**: `Upload bank or custody statements (CSV, XLSX, PDF)` in 14 pt regular, `#4A4A4A`

## Section B – Import Cards
Two cards share the width equally. Each provides drag & drop upload and a file picker.

| Credit-Suisse Card | ZKB Card |
| --- | --- |
| 48×48 px logo icon | 48×48 px logo icon |
| Heading: **Import Credit-Suisse Statement (Position List M DD YYYY.xls)** | Heading: **Import ZKB Statement** |
| Drag & Drop zone, 120 px tall with dashed border and 6 px radius. Centered icon and hint text `Drag & Drop Credit-Suisse File` (`13 pt`, `#888`). | Same style. Text `Drag & Drop ZKB File` and highlight on hover. Disabled until parser is ready. |
| "or" separator (`12 pt`, `#AAA`) | "or" separator |
| `Select File` button (`32 px` high, outline style, fills on hover) | `Select File` button (disabled with tooltip "coming soon") |

On screens ≤ 600 px the cards stack vertically and use 100% width with 16 px spacing.

## Section C – Import Summary Bar
Hidden until an import succeeds. Displays a green check icon followed by a short summary such as:

> ✔ Credit-Suisse import succeeded: 45 records parsed, 2 errors.

The text is 14 pt in `#2E7D32` and aligned below the cards. A `View Details…` link reveals per-entry information.

## Section D – Statement Loading Log
Below the summary bar is a framed log listing recent uploads. This mirrors the Database Management **Backup & Restore Log**.

- White background with 1 px border `#E0E0E0` and 6 px radius
- Title inside the frame: **Statement Loading Log** in 14 pt bold, `#333`
- Log lines use a monospaced font at 12 pt, `#222`
- Each line follows `[timestamp] filename → status` format, e.g.
```
[2025-07-12 08:35:42] Credit-Suisse_Positions_2025-07-12.csv → Success: 45 records.
[2025-07-12 08:37:10] ZKB_Positions_2025-07-12.xlsx → Failed: parser not available.
```
- Fixed height of 160 px with vertical scroll if entries overflow
- Margin-top: 24 px from the summary bar

## Responsive Behaviour
- Below 600 px width, import cards stack vertically (100% width) with 16 px spacing
- The Statement Loading Log spans the full width at all sizes

## Final Wireframe (Desktop)
```
──────────────────────────────────────────────────────────
| Data Import / Export                                  |
| Upload bank or custody statements (CSV, XLSX, PDF)   |
──────────────────────────────────────────────────────────
| ┌──────────────┐  ┌───────────────┐                    |
| │[CS Icon]     │  │[ZKB Icon]     │                    |
| │Import CS     │  │Import ZKB     │                    |
| │┌──────────┐  │  │┌───────────┐  │                    |
| ││ Drag &   │  │  ││ Drag &    │  │                    |
| ││ Drop CS  │  │  ││ Drop ZKB  │  │                    |
| │└──────────┘  │  │└───────────┘  │                    |
| │    or        │  │    or        │                    |
| │[Select CS]   │  │[Select ZKB]  │                    |
| └──────────────┘  └───────────────┘                    |
──────────────────────────────────────────────────────────
| ✔ Last import: Credit-Suisse – 45 records parsed      |
──────────────────────────────────────────────────────────
| Statement Loading Log                                 |
| ┌──────────────────────────────────────────────────┐   |
| │[2025-07-12 08:35:42] CS_Positions_…csv → Success…│   |
| │[2025-07-12 08:37:10] ZKB_Positions_…xlsx → Failed │   |
| │…                                                │   |
| └──────────────────────────────────────────────────┘   |
──────────────────────────────────────────────────────────
```
