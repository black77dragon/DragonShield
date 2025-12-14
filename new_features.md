# Project Features and Change Log

This document serves as a central backlog for all pending changes, new features, and maintenance tasks for the DragonShield project. It tracks the lifecycle of features from request to implementation.

**Instructions:**
- Add new requests to the Backlog with a unique ID (e.g., `DS-006`) and include context ("Why") plus acceptance criteria ("What").
- Tag each Backlog entry with `[bugs]`, `[changes]`, or `[new_features]` based on the request text; if the fit is unclear, ask the user to clarify before adding or updating the item.
- When work starts on a backlog item, mark it with `[*]`, keep it in the Backlog, and move it to the top of the Backlog list. Use the in-progress format `[*] [new_features] [DS-031]` (with the item’s own tag/ID).
- After the user confirms testing and explicitly asks to move it, shift the item to **Implemented**, mark it with `[x]`, and append the move date (YYYY-MM-DD) to the entry.

## Backlog

- [ ] [new_features] **[DS-033] Risk Engine Fallbacks & Flags**
    Why: Ensure robust risk classification even when data is missing or stale, and surface quality signals to users.
    What: Implement PRIIPs-style volatility fallback bucketing when mapping is missing; mark profiles using fallbacks and expose unmapped/stale flags (`recalc_due_at`, missing inputs) in the Risk Report, Maintenance GUI, and instrument detail; default conservative values when data is absent (e.g., SRI 5, liquidity Restricted).

- [ ] [changes] **[DS-048] Review Ichimoku Cloud Implementation**
    Why: Ensure the Ichimoku Cloud indicator matches standard calculations and visuals so signals remain trustworthy.
    What: Audit the Ichimoku computation and plotting (conversion/base lines, leading spans, lagging line, defaults/offsets) against the reference spec, fix any deviations, and document expected behavior plus tests.

- [ ] [changes] **[DS-019] Drop "Order" column in next DB update**
    Why: The "Order" attribute is being retired and should be removed from the schema to simplify maintenance. What: In the next database update, add a migration to drop the "Order" column from Instrument Types, update ORM/model definitions and queries to match, and document the schema change in the release notes for the database update.

- [ ] [changes] **[DS-025] Drop Order Column from Asset Class Table**
    Why: The "Order" column is unused and should be removed to simplify the schema. What: Add a database migration to remove the "Order" column from the Asset Class table and update related models/ORM mappings and queries accordingly.

## Implemented

- [x] [new_features] **[DS-051] Add Risk Management to iOS App** (2025-12-14)
    Why: Mobile users currently lack risk management screens and reports available on desktop, limiting their ability to review and act on risk while away from a workstation.
    What: Bring the Risk Management functionality to the iOS app, including navigation entry, risk maintenance views, and risk reports (risk score, SRI/liquidity distributions, overrides) with parity to desktop interactions and formatting.

- [x] [bugs] **[DS-059] Align Risk Report Portfolio Risk Score with Dashboard** (2025-12-14)
    Why: The Risk Report shows a different portfolio risk score than the dashboard because it uses raw import prices without FX and ignores the liquidity premium/clamp.
    What: Recompute the Risk Report portfolio score using latest prices converted to base currency, apply the same SRI + liquidity premium logic as the dashboard (clamped 1–7), and keep totals/percentages in sync with the dashboard snapshot.

- [x] [new_features] **[DS-058] Add Exposure Heatmap to Risk Report GUI** (2025-12-14)
    Why: Risk reviewers need a visual that highlights allocation concentration by segment with both percentage of total asset value and CHF amounts so they can spot hot spots quickly.
    What: Add an exposure heatmap panel to the Risk Report GUI showing each segment’s percentage share of total asset value and the corresponding CHF value; align segments with the existing risk categories, and include clear labels/legend so both % and CHF figures are visible in the heatmap.

- [x] [changes] **[DS-057] Remove Trends Graph from Risk Report GUI** (2025-12-14)
    Why: The Trends graph in the Risk Report is unused and consumes space that should highlight the actionable risk visuals.
    What: Remove the Trends graph panel (chart, title, legend, and related controls) from the Risk Report GUI; reflow remaining cards/sections so there is no empty gap, and ensure no dead menu entries or links still point to the removed graph.

- [x] [new_features] **[DS-055] Add Irreversible Portfolio Delete in Danger Zone (No Holdings Only)** (2025-12-14)
    Why: Users need a safe way to permanently remove empty portfolios while preventing accidental deletion of portfolios that still contain holdings.
    What: In the Portfolio Danger Zone, add a "Delete Portfolio" action that is only enabled when the portfolio has zero holdings; trigger a confirmation popup that clearly states the deletion is permanent/irreversible and requires explicit user confirmation before proceeding.

- [x] [bugs] **[DS-056] Fix Portfolio Total Tal Column Uses Excluded Sum** (2025-12-13)
    Why: In the Portfolio View, the "Total Tal (CHF)" column currently shows the total value including excluded amounts, misleading users about the included portfolio value.
    What: Update the "Total Tal (CHF)" column to display only the included total value in CHF (excluding excluded sums), keeping formatting consistent with other monetary columns.

- [x] [bugs] **[DS-054] Fix Soft Deleted/Archived Theme Toggles in Portfolio Settings** (2025-12-13)
    Why: In the Portfolio View settings tab, the "Soft Deleted" and "Archived" theme buttons can be clicked but do not show their active state, leaving users unsure whether the filters are applied.
    What: Make the "Soft Deleted" and "Archived" theme buttons behave as toggles that visually reflect their activated state, maintain state when selected/deselected, and ensure the Portfolio View responds according to the active selections.

- [x] [changes] **[DS-038] Align Dashboard Tile Dimensions**
    Why: The Dashboard tiles have inconsistent sizing and shapes, making the canvas look uneven.
    What: In the Dashboard GUI, ensure the "Instrument Dashboard" and "Today" tiles use the same height, width, and rounded-corner shape as the "Total Asset Value (CHF)" tile within the same canvas.

- [x] [changes] **[DS-053] Color-Code Portfolio Updated Date**
    Why: Portfolio viewers need a quick freshness signal for portfolio data to spot stale updates.
    What: In the Portfolio GUI, color the "Updated" date text red when older than 2 months, amber when between 1–2 months, and green when within the past month based on today's date.

- [x] [changes] **[DS-050] Refine Portfolio Risks Tab for Actionable Use**
    Why: The current Risks tab is text-heavy, lacks filters or drill-downs, and does not clearly surface high-risk/illiquid concentrations or data-quality warnings, so portfolio managers cannot act on the risk score.
    What: Redesign the Risks tab with an actionable hero (risk score gauge with base currency/as-of, high-risk 6–7 and illiquid callouts), SRI and liquidity donuts with Count/Value toggles that filter the list, and a sortable/searchable contributions table showing value, weight, SRI, liquidity, blended score, and badges for fallbacks/overrides; add chips for quick filters (High risk, Illiquid, Missing data) plus drill-through to Instrument Maintenance/Risk profile and an export to CSV of the filtered table; surface coverage/fallback warnings with counts for missing FX/price/mapping and expiring overrides.

- [x] [new_features] **[DS-052] Show Price Staleness on Total Asset Value Tile**
    Why: Dashboard viewers need to see how fresh the Total Asset Value figure is before acting on it, especially when prices might be stale.
    What: In the Dashboard's "Total Asset Value (CHF)" tile, display the hours since the last price update directly under the current value (e.g., "Updated 3.2h ago") and refresh it whenever prices are updated.

- [x] [bugs] **[DS-040] Align Portfolios Table Headers with Content**
    Why: In the Portfolios GUI the column headers become offset and do not scroll with the table contents, making the list hard to read.
    What: Build a new alternate Portfolios view using the working table layout pattern so header and rows scroll together; keep the legacy view available until the new version is verified, then remove the old implementation.

- [x] [new_features] **[DS-029] Add Risk Tiles to Dashboard**
    Why: Users want an at-a-glance view of portfolio risk posture directly on the dashboard.
    What: Add Risk Tiles to the Dashboard GUI showing key risk aspects (e.g., SRI distribution, liquidity tiers, overrides) using graphical donut charts; enable drill-down from each tile to show the underlying instruments and details.

- [x] [new_features] **[DS-035] Risk Dashboard Tiles with Drill-Down**
    Why: Provide at-a-glance risk posture on the main dashboard with quick drill-down.
    What: Add dashboard tiles for SRI distribution, liquidity tiers, and active overrides using donut charts; each slice opens a filtered list of underlying instruments; include badges for high-risk (SRI 6–7) and illiquid percentages.

- [x] [new_features] **[DS-039] Show Portfolio Risk Score in Portfolio Table**
    Why: Portfolio managers need to see portfolio risk posture at a glance without opening each portfolio.
    What: In the Portfolios GUI overview/table, add a "Risk Score" column showing the computed portfolio risk score (from DS-032) with sorting and standard formatting so users can compare portfolios directly.

- [x] [changes] **[DS-049] Color-Code Risk Score Tile Slider**
    Why: Users need an immediate visual cue on whether the risk score trends low or high without reading labels.
    What: In the Risk Score tile, keep showing the current risk score number and color the slider from green on the left (low risk) to red on the right (high risk), with the thumb/track reflecting the color at the score position.

- [x] [changes] **[DS-047] Relocate Development/Debug Options Tile**
    Why: The Development/Debug options tile clutters the Settings GUI and belongs with data utilities.
    What: Move the "Development/Debug options" tile out of Settings and into the Data Import/Export GUI, keeping its functionality unchanged in the new location.

- [x] [bugs] **[DS-041] Backup Database Script Missing**
    Why: The "Backup Database" action fails because `/Applications/Xcode.app/Contents/Developer/usr/bin/python3` cannot find `python_scripts/backup_restore.py`, preventing backups from running.
    What: Restore or relocate the backup/restore Python script and update the command/path so the Backup Database flow completes successfully on macOS, with a check that the script exists before execution.

- [x] [changes] **[DS-037] Simplify Sideview Menu (Systems Section)**
    Why: The Systems menu contains rarely used items that clutter navigation and confuse users.
    What: Audit the Systems section of the sideview menu to identify consolidation opportunities and unused entries (e.g., "Ichimoku Dragon"); grey out any unused/legacy items in the menu and provide a streamlined set of active options.

- [x] [changes] **[DS-043] Standardize Table Spacing**
    Why: User-adjustable table spacing/padding creates inconsistent table layouts and adds settings that diverge from the Design System defaults.
    What: Audit all uses of the Settings-driven table spacing/padding, replace them with the standard application defaults, and remove the "Table Display Settings" section from Settings once the swap is complete.

- [x] [changes] **[DS-045] Relocate Risk Management Menu Entry**
    Why: The "Risk Management" entry currently sits under the Portfolio section, making the configuration item hard to find and inconsistent with other maintenance screens.
    What: Move the "Risk Management" sideview menu entry from the Portfolio group into the Configuration section and rename it to "Instrument Risk Maint." to match the desired naming.

- [x] [changes] **[DS-044] Consolidate Application Startup into Systems GUI**
    Why: The standalone Application Startup GUI duplicates navigation and clutters the sideview.
    What: Move all Application Startup content/controls into the Systems GUI and remove the "Application Startup" entry from the sideview menu, keeping functionality unchanged in its new location.

- [x] [bugs] **[DS-042] Validate Instruments Button Does Nothing**
    Why: In the Database Management GUI, pressing "Validate Instruments" shows no visible action or feedback, so users cannot tell whether validation is running or completed.
    What: Fix the Validate Instruments implementation so the validation executes and surfaces progress/result feedback; add a short light-grey description (matching the Application Start Up GUI style) explaining the purpose of the Validate Instruments function.

- [x] [changes] **[DS-046] Rework Settings Layout**
    Why: The Settings screen layout buries the About info, shows unused fields, and lacks a clear header for health status.
    What: In the Settings GUI, place the "About" canvas at the top-left and "App Basics" at the top-right; remove/hide the "Base Currency" and "Decimal Precision" fields since they are unused; add a "Health Checks" header above the line starting with "Last Result ...".

- [x] [changes] **[DS-040] Simplify Portfolio Status Indicator**
    Why: The Portfolios table shows two color-coded status visuals (icon plus small bubble), cluttering the column.
    What: In the Portfolios GUI Status column, remove the larger color icon and retain only the small bubble as the status indicator.

- [x] [new_features] **[DS-032] Define Portfolio Risk Scoring Methodology**
    Why: We need a clear, consistent way to compute a portfolio risk score using instrument-level risk and allocation.
    What: Specify and implement a methodology to calculate portfolio risk that weights each instrument's risk score (SRI/liquidity) by its allocated value, producing a portfolio-level score and category for use in dashboards, reports, and the new Risks tab.

- [x] [new_features] **[DS-031] Portfolio Risk Scoring & Tab**
    Why: Portfolio managers need a simple risk score per portfolio and per constituent to assess posture quickly.
    What: Compute a risk score for each portfolio (e.g., weighted SRI/illiquidity) and display it in the Portfolios GUI; add a "Risks" tab in Portfolio Maintenance showing the total portfolio risk score plus the risk (SRI/liquidity) of each instrument.

- [x] [new_features] **[DS-030] Enhance Risk Report with Actionable Visuals**
    Why: Users need to spot risk hot spots quickly and know where to act.
    What: Add graphical diagrams to the Risk Report: SRI distribution and allocation as donuts/bars with clickable slices; liquidity tiers as a donut with drill-down; a heatmap of top exposures vs. risk buckets; and a panel highlighting overrides/expiries with jump-to instrument actions.

- [x] [new_features] **[DS-028] Drill-Through to Instrument Maintenance from Risk Report** (2025-12-14)
    Why: Analysts need to jump from Risk Report drilldowns directly into instrument maintenance to review or adjust details without leaving context.
    What: In the Risk Report GUI, when detailed instrument lists are shown in SRI Distribution, SRI Distribution (Value), and Liquidity sections, make each instrument row clickable and open the Instrument Maintenance GUI for that instrument.

- [x] [new_features] **[DS-036] Portfolio Risks Tab with Instrument Breakdown**
    Why: Portfolio maintenance needs a dedicated risk view.
    What: Add a "Risks" tab in Portfolio Maintenance showing the portfolio risk score (from DS-032), the distribution of instruments by SRI/liquidity (count and value), and a table of constituents with their SRI, liquidity tier, and weighted contribution; allow sorting and export.

- [x] [new_features] **[DS-027] Introduce Instrument-Level Risk Concept**
    Why: We need a standardized risk label per instrument, aligned with market conventions, to support controls, dashboards, and reporting.
    What: Document and adopt the new risk concept (`risk_concept.md`) that scores each instrument into a risk type using volatility, asset class, duration/credit, liquidity, leverage/derivatives, and currency factors, then store the resulting risk type on instruments for downstream UI and reports.

- [x] [new_features] **[DS-026] Add Instrument Types Export Button**
    Why: Users need a quick way to extract instrument type definitions for audits and bulk edits without querying the database. What: In the Instrument Types GUI, add a button that generates a text file named "dragonshield_instrument_types.txt" containing a table of all instrument types with the columns: Instrument Type Name, Asset Class, Code, Description.

- [x] [changes] **[DS-022] Sort Instruments by Prices As Of in Update Prices Window**
    Why: Users want to quickly find the most recent prices when updating accounts. What: In the "Update Prices in Account" GUI, sort the instrument list by the "Prices As Of" column (most recent first) so the freshest data is surfaced by default.

- [x] [changes] **[DS-020] Show Current Price & Date in Update Prices Window** (2025-12-14)
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

- [ ] [new_features] **[DS-034] Override Governance Cues (Read-Only Surfaces)**
    Why: Users need visibility into manual overrides outside the edit screens.
    What: In dashboards, Risk Report, and instrument read-only contexts, display override badges with computed vs. override values, who/when/expiry, and highlight expiring/expired overrides; include jump-to-maintenance links where applicable.

- [ ] [changes] **[DS-006] Harmonize Price Maintenance View**
    Upgrade `PriceMaintenanceSimplifiedView.swift` to use the Design System. This is a data-heavy view, so focus on readability and table styling.
