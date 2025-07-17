# Allocation Targets Table View Refinement Specification

## Purpose
Provide detailed requirements for improving the `AllocationTargetsTableView` in the macOS app so users can better understand sorting behaviour and quickly identify zero allocation assets.

## Sorting Indicators
- Both the **Target %** and **Actual %** column headers must always display a sort arrow.
- When a column is the active sort key, show a **filled arrow** in the system accent colour.
- When a column is not active, show an **outlined arrow** coloured grey.
- The arrow direction reflects ascending or descending order of the active comparator.
- Sorting remains single-column only; clicking a header toggles its ascending/descending state and resets the other column to inactive.

## Row Grouping
- Assets with both `targetPct` and `actualPct` equal to `0` are considered *zero‑allocation rows*.
- Display all non‑zero rows first in the table.
- Insert a header row labelled **"Zero Allocation"** before listing zero‑allocation rows.
- Render zero‑allocation rows with reduced opacity so they appear visually distinct but remain legible.

## Accessibility
- Custom table headers must combine the text label and arrow icon into one accessible element.
- VoiceOver should announce the column title and current sort order when focus lands on the header button.

## Implementation Notes
- Use `TableColumn` with a custom header view that stacks `Text(title)` and `Image(systemName: ...)`.
- SF Symbols: `arrowtriangle.up.fill` / `arrowtriangle.down.fill` for the active column; `arrowtriangle.up` / `arrowtriangle.down` for inactive.
- Determine the active sort column by comparing the stored `KeyPathComparator` with each column’s key path.
- Split the assets array into `nonZeroAssets` and `zeroAssets` before populating the `List` or `OutlineGroup`.
- Apply `opacity(0.6)` (approximate) to the zero‑allocation rows.

