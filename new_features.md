# Project Features and Change Log

This document serves as a central backlog for all pending changes, new features, and maintenance tasks for the DragonShield project. It tracks the lifecycle of features from request to implementation.

**Instructions:**
- Add new requests to the Backlog with a unique ID (e.g., `DS-006`) and include context ("Why") plus acceptance criteria ("What").
- Tag each Backlog entry with `[bugs]`, `[changes]`, or `[new_features]` based on the request text; if the fit is unclear, ask the user to clarify before adding or updating the item.
- When work starts on a backlog item, mark it with `[*]` to show it is in progress and keep it in the Backlog.
- After the user confirms testing and explicitly asks to move it, shift the item to **Implemented** and mark it with `[x]`.

## Backlog

- [ ] [new_features] **[DS-027] Introduce Instrument-Level Risk Concept**
    Why: We need a standardized risk label per instrument, aligned with market conventions, to support controls, dashboards, and reporting.
    What: Document and adopt the new risk concept (`risk_concept.md`) that scores each instrument into a risk type using volatility, asset class, duration/credit, liquidity, leverage/derivatives, and currency factors, then store the resulting risk type on instruments for downstream UI and reports.

- [ ] [changes] **[DS-019] Drop "Order" column in next DB update**
    Why: The "Order" attribute is being retired and should be removed from the schema to simplify maintenance. What: In the next database update, add a migration to drop the "Order" column from Instrument Types, update ORM/model definitions and queries to match, and document the schema change in the release notes for the database update.

- [ ] [changes] **[DS-025] Drop Order Column from Asset Class Table**
    Why: The "Order" column is unused and should be removed to simplify the schema. What: Add a database migration to remove the "Order" column from the Asset Class table and update related models/ORM mappings and queries accordingly.

## Implemented

- [x] [new_features] **[DS-026] Add Instrument Types Export Button**
    Why: Users need a quick way to extract instrument type definitions for audits and bulk edits without querying the database. What: In the Instrument Types GUI, add a button that generates a text file named "dragonshield_instrument_types.txt" containing a table of all instrument types with the columns: Instrument Type Name, Asset Class, Code, Description.

- [x] [changes] **[DS-022] Sort Instruments by Prices As Of in Update Prices Window**
    Why: Users want to quickly find the most recent prices when updating accounts. What: In the "Update Prices in Account" GUI, sort the instrument list by the "Prices As Of" column (most recent first) so the freshest data is surfaced by default.

- [x] [changes] **[DS-020] Show Current Price & Date in Update Prices Window**
    Why: Users need context on the existing recorded price before applying updates so they can confirm they are overwriting the right value. What: In the "Update Prices in Account" window, display the current price and its date as greyed-out, read-only information (no edits allowed) alongside the update fields, ensuring the values reflect the selected instrument/account.

- [x] [new_features] **[DS-023] Add Asset Management Report to iOS**
    Why: Mobile users need the same Asset Management insights available on desktop. What: Implement the "Asset Management Report" in the iOS app with the existing report logic and filters (accounts/date range), accessible from the mobile Reports menu, and ensure the rendered output matches the current report formatting.

- [x] [changes] **[DS-021] Remove Order Logic from Instrument Types UI**
    Why: The "Order" field is no longer required and should not appear in the Instrument Types GUI. What: Remove the Order field/logic from the Instrument Types screens while leaving the database column untouched, and ensure the table supports sorting by each header using the standard DragonShield table interaction pattern.

- [x] [changes] **[DS-024] Remove Order Field from Asset Classes View**
    Why: The "Order" field is no longer needed and clutters the UI. What: Update the Asset Classes GUI to remove the "Order" field from forms/tables while leaving the database unchanged.

- [x] [changes] **[DS-018] Remove "Order" from Instrument Types UI**
    Why: The "Order" attribute is unused and confuses users when creating or editing instrument types. Keep the column in the database for now but stop exposing or relying on it in the app. What: Remove the "Order" field from the Instrument Types GUI and the "New Instrument Type" window, eliminate any code references/validation bindings to the field while leaving the database column untouched, and ensure existing instrument type flows still compile and function without the attribute.

- [x] **[DS-017] Refresh Dashboard Total Asset Value**
    When prices are updated via the price update button in the Dashboard's upper right, immediately refresh the Total Asset Value tile using the new prices and show the delta from the previous value (green if positive, red if negative) so the tile always reflects current data.

- [x] **[DS-001] Fix Instrument Edit Save Button**
    In the "Edit Instrument" GUI, the "Save" button is unresponsive. Specifically, after pressing the button, the window does not close automatically, giving the impression that the action failed.

- [x] **[DS-002] Harmonize Asset Classes View**
    Upgrade `AssetClassesView.swift` to use the DragonShield Design System (`DSColor`, `DSTypography`, `DSLayout`). Ensure consistent styling for lists, headers, and buttons.

- [x] **[DS-003] Harmonize Currencies View**
    Upgrade `CurrenciesView.swift` to use the Design System. Focus on table layouts, status badges, and action buttons.

- [x] **[DS-004] Harmonize Instrument Types View**
    Upgrade `InstrumentTypesView.swift` to use the Design System. Ensure consistency with other configuration views.

- [x] [changes] **[DS-009] Harmonize Data Import/Export**
    Upgrade `DataImportExportView.swift` and `DatabaseManagementView.swift` to use standard Design System components.

- [x] **[DS-005] Harmonize Institutions View**
    Upgrade `InstitutionsView.swift` to use the Design System. This includes the list of institutions and any detail/edit forms.

- [x] **[DS-007] Harmonize Transaction Types View**
    Upgrade `TransactionTypesView.swift` to use the Design System.

- [x] **[DS-008] Harmonize Reports Views**
    Review and upgrade `AssetManagementReportView.swift` and `FetchResultsReportView.swift` to ensure generated reports align with the new aesthetic.

- [x] **[DS-012] Fix Account Price Update Flow (2026-02-06)** From the Dashboard's "accounts need updating" tile, the "latest price" update now persists the latest price with today's date in the instrument prices table and shows a confirmation popup (price + date with an "OK" button) after a successful update that closes upon acknowledgment.
- [x] **[DS-013] Move Transactions to Portfolio Sidebar (2025-11-25)** Transactions link moved from System group to Portfolio group under Positions.
- [x] **[DS-010]** Improve contrast in Edit Instrument GUI (change white fields to light grey)
- [x] **[DS-011] Rename Accounts Update Dialog** Dialog now titled "Update Prices in Account" when opened from the "accounts need updating" tile.
- [x] **[DS-014] Tighten Dashboard Tile Padding**
    In the Dashboard view's horizontal canvas with three tiles, the lower padding/white space has been reduced so the distance from the tile border to the title/text matches the top spacing.
- [x] **[DS-015] Rename Asset Classes Navigation & Tabs**
    Update the sidebar menu item label from "Asset Classes" to "Asset Classes & Instr. Types". In the Asset Classes maintenance window, rename the tab buttons "Classes" → "Asset Classes" and "Sub Classes" → "Instrument Types" for clarity.
- [x] **[DS-016] Update DragonShield Logo**
    Replace existing logo assets with the latest DragonShield branding and ensure the updated logo appears consistently in the app icon, splash/loading screens, and primary navigation.

## Postponed Features

- [ ] [changes] **[DS-006] Harmonize Price Maintenance View**
    Upgrade `PriceMaintenanceSimplifiedView.swift` to use the Design System. This is a data-heavy view, so focus on readability and table styling.
