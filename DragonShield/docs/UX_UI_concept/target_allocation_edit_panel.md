# Target Allocation Edit Panel

This document outlines the side‑panel workflow for editing Asset Class targets along with their Sub‑Classes. The goal is a minimal, fool‑proof UI that stores either percentage or CHF values per class, never a mix.

## Core Rules
1. The parent Asset Class selects **Target Kind** – either percentage (%) or amount in CHF. When Sub‑Classes already exist, the radio buttons are disabled so the kind matches existing children.
2. Validation differs by kind:
   - **Percent** – the sum of child percentages must equal `100 %`.
   - **CHF** – the sum of child CHF amounts must equal the parent amount.
3. The **Save** button only enables when all panels pass validation.
4. An optional **Auto‑balance** button distributes any remainder across unlocked rows.

## Layout
```
  ◁ Back          Edit targets — [Asset Class]
  ──────────────────────────────────────────────
  TARGET KIND     (•) %   ( ) CHF
  TARGET VALUE    [ 25.0 ] %
  ──────────────────────────────────────────────
  SUB‑CLASS TARGETS
  +----------------------------+-----------+
  | Sub‑class                  | Target    |
  +----------------------------+-----------+
  | Large Cap                  | [ 15.0 ] %|
  | Small Cap                  | [  5.0 ] %|
  | Emerging Markets           | [  5.0 ] %|
  +----------------------------+-----------+
  Remaining to allocate: 0.0 %
  ( Auto‑balance )  ( Cancel )  ( Save )
```
- The remaining line turns red when non‑zero.
- Auto‑balance fills the remainder proportionally across editable rows.
- Save stays disabled until remaining equals zero.
- A pencil button appears next to each Asset Class target column. Clicking it or
  double‑clicking the row opens the side‑panel editor. The same action is
  available via **Enter** or **Space** on the focused row. The active row
  highlights light blue while editing.

## Validation Logic (pseudo)
```swift
if parent.kind == .percent {
    parentOK = abs(sum(child.percent) - 100.0) < 0.1
} else {
    parentOK = abs(sum(child.amount) - parent.amount) < 1.0
}
canSave = parentOK && rootOK && allTargetsPositive()
```

## Auto‑balance Algorithm
```
remainder = 100 - Σ currentChildren%
unlocked = children.filter { !isLocked($0) }
share = remainder / unlocked.count
for row in unlocked { row.value += share }
round rows to 0.1 precision
adjust last row to remove rounding drift
```

The CHF path works identically using money units.

## Edge Cases
1. Parent in CHF 1 000 000, children total 950 000 → Remaining −50 000 CHF.
   - Save disabled, Remaining turns red, Auto‑balance distributes 50 000 CHF.
2. Parent in %; user edits Large Cap from 15.0 → 20.0.
   - Remaining shows −5.0 % until another row decreases by 5.0 %.
3. User switches kind from % → CHF while children exist.
   - Radio buttons are locked with a tooltip stating the kind is fixed by existing children.
```
