# Edit Targets Panel Specification

## Overview
The Edit Targets panel allows users to review and modify asset allocation targets for a selected asset class and its sub-classes. Targets can be specified either as a percentage of the total portfolio or as a CHF amount. The panel supports bi-directional conversion between percentage and CHF values, persists all changes, and performs non-blocking validation with detailed logging.

## Behaviour
1. **Load & Display**
   - On appearing, the panel fetches `target_percent`, `target_amount_chf`, `target_kind`, and `tolerance_percent` from `TargetAllocation` for the parent asset class and each visible sub-class.
   - Loaded values are displayed without defaulting to zero.
   - Parent and sub-class rows show both **Target %** and **Target CHF** fields side by side.
   - The field corresponding to the stored `target_kind` is editable (black text); the other field is read-only (grey).

2. **Bi-Directional Calculation**
   - Editing **Target %** recalculates **Target CHF** using the total portfolio value for parents and the parent’s CHF target for sub-classes.
   - Editing **Target CHF** recalculates **Target %** using the same basis.
   - Calculated values update immediately and emit debug logs tagged `[CALC %→CHF]` or `[CALC CHF→%]`.

3. **Persistence**
   - Pressing **Save** writes `target_percent`, `target_amount_chf`, `target_kind`, and `tolerance_percent` for the parent and each sub-class back to `TargetAllocation`.
   - Each write is logged with `[DB WRITE]`.

4. **Validation**
   - After saving, the panel validates allocations:
     - Sum of all parent percentages must equal 100%.
     - Sum of all parent CHF amounts must equal the portfolio total.
     - For each parent with a non-zero target, sub-class percentages must sum to 100% and CHF amounts to the parent’s CHF target.
   - Any mismatches are collected as warnings, logged with `[VALIDATION WARN]`, and displayed in a “Validation Warnings” section within the panel.
   - Validation warnings never block saving.

5. **Logging**
   - `[EDIT PANEL LOAD]` – fetching and displaying initial values.
   - `[CALC %→CHF]` / `[CALC CHF→%]` – user-triggered conversions.
   - `[DB WRITE]` – database persistence.
   - `[VALIDATION WARN]` – validation failures.

## Implementation Checklist
- [ ] Fetch and display existing targets for the selected asset class and its sub-classes on panel open.
- [ ] Render both percent and CHF fields for every row, enabling only the field matching `target_kind`.
- [ ] Implement bi-directional conversions with immediate updates and logging.
- [ ] Persist `target_percent`, `target_amount_chf`, `target_kind`, and `tolerance_percent` for all rows on save.
- [ ] Perform post-save validation and surface warnings in-panel without blocking the save.
- [ ] Tag logs according to the categories above for traceability.
