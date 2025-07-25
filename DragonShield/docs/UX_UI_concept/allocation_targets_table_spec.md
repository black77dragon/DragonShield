# Allocation Targets Table View Refinement Specification

## Purpose
Provide detailed requirements for improving the `AllocationTargetsTableView` in the macOS app so users can better understand sorting behaviour and quickly identify zero allocation assets. Each asset row exposes three percentage values: `targetPct`, `actualPct` and `deltaPct` (**Delta %**).

## Assumptions & Context
- Built with the SwiftUI **Table** API on macOS 13 or later.
- Sorting uses a single `KeyPathComparator` stored in a `@State` property so only one column is sortable at a time.
- Asset rows expose `targetPct`, `actualPct` and `deltaPct` percentage fields.
- *Zero allocation* rows have all three percentages set to `0`.

## Sorting Indicators
- The **Target %**, **Actual %** and **Delta %** (Δ) column headers must always display a sort arrow.
- When a column is the active sort key, show a **filled arrow** in the system accent colour.
- When a column is not active, show an **outlined arrow** coloured grey.
- The arrow direction reflects ascending or descending order of the active comparator.
- Sorting remains single-column only; clicking a header toggles its ascending/descending state and resets the other columns to inactive.

## Row Grouping
- Assets with `targetPct`, `actualPct` and `deltaPct` all equal to `0` are considered *zero‑allocation rows*.
- Display all non‑zero rows first in the table.
- Insert a header row labelled **"Zero Allocation"** before listing zero‑allocation rows.
- Render zero‑allocation rows with reduced opacity so they appear visually distinct but remain legible.

## Accessibility
- Custom table headers must combine the text label and arrow icon into one accessible element.
- VoiceOver should announce the column title and current sort order when focus lands on the header button.

## Implementation Notes
- Use `TableColumn` with a custom header view that stacks `Text(title)` and `Image(systemName: ...)` for each sortable column.
- SF Symbols: `arrowtriangle.up.fill` / `arrowtriangle.down.fill` for the active column; `arrowtriangle.up` / `arrowtriangle.down` for inactive.
- Determine the active sort column by comparing the stored `KeyPathComparator` with the `targetPct`, `actualPct` or `deltaPct` key path.
- Split the assets array into `nonZeroAssets` and `zeroAssets` before populating the `List` or `OutlineGroup`.
- Apply `opacity(0.6)` (approximate) to the zero‑allocation rows.

