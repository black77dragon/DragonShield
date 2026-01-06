# Project Features and Change Log

This document serves as a central backlog for all pending changes, new features, and maintenance tasks for the DragonShield project. It tracks the lifecycle of features from request to implementation.

**Instructions:**
- Add new requests to the Backlog with a unique ID (e.g., `DS-006`) and include context ("Why") plus acceptance criteria ("What").
- Tag each Backlog entry with `[bugs]`, `[changes]`, or `[new_features]` based on the request text; if the fit is unclear, ask the user to clarify before adding or updating the item.
- When work starts on a backlog item, mark it with `[*]`, keep it in the Backlog, and move it to the top of the Backlog list. Use the in-progress format `[*] [new_features] [DS-031]` (with the item’s own tag/ID).
- After the user confirms testing and explicitly asks to move it, shift the item to **Implemented**, mark it with `[x]`, and append the move date (YYYY-MM-DD) to the entry.
- This file is the source of truth for release status. `CHANGELOG.md` is generated from **Implemented** items here plus Git tags. Do not hand-edit `CHANGELOG.md`.
- Keep Implemented items dated so they can be mapped to tags correctly.
- Before each release, tag `vX.Y.Z`, ensure `VERSION` matches, then run the sync script (`python3 scripts/sync_changelog.py` or Settings → Release Notes Sync). Use `GITHUB_TOKEN` if you want GitHub release body notes included.
- Optional: run the sync script with `--dry-run` in CI or a pre-commit check to catch drift early.

## Backlog

- <mark>[*] [bugs] **[DS-090] Release Notes Show v1.39.0 While App Is v1.40.0**</mark>
    Why: The sidebar shows version 1.40.0, but the Release Notes window highlights v1.39.0, so users think the latest features are missing or not released.
    What: Problem analysis: `ReleaseNotesView` always calls `ReleaseNotesProvider.loadAll()` and never uses the current app version, so the UI highlights the latest dated section in `CHANGELOG.md`. Because the bundled `CHANGELOG.md` still tops out at v1.39.0 (v1.40.0 is still under Unreleased due to missing tag/sync), the popup defaults to v1.39.0 and omits v1.40.0 features from the "latest release" grouping. Resolution strategy: (1) finalize the release flow by tagging `v1.40.0`, running `scripts/sync_changelog.py`, and ensuring the updated `CHANGELOG.md` is bundled so v1.40.0 exists as a dated section; (2) update `ReleaseNotesView` to call `ReleaseNotesProvider.load(for: AppVersionProvider.version)` and fall back to Unreleased with a clear note when the version is missing; (3) add a build-time or startup check that logs/alerts when the app version is not found in the changelog to prevent future drift.

- <mark>[ ] [changes] **[DS-091] iOS To-Do Board Dark Mode for Readability**</mark>
    Why: The current iOS To-Do Board appearance is barely readable, so users cannot comfortably read or manage tasks.
    What: Update the iOS To-Do Board representation to a dark-mode style that materially improves text/background contrast and overall legibility; ensure key elements (columns, cards, titles, status indicators, and action buttons) remain readable in the new styling and align with the iOS design system used elsewhere.

- <mark>[ ] [new_features] **[DS-077] Monthly Deep Dive Check**</mark>
    Why: Portfolio managers need a structured monthly deep dive to reassess regime, sizing, and behavior patterns, and to keep capital intent aligned with life-stage goals.
    What: For every portfolio, add a Monthly Deep Dive Check workflow (60-90 minutes, once per month) that records completion and written outputs. Show the next check due date, the last completed check date, and a history list with timestamps and viewable past responses. The GUI must include guidance for each section (inline helper text or hover tips). Before implementation, determine the best UX/UI design for where this lives, how scheduling/reminders work, how responses are captured, how guidance is presented, and how completion/history are tracked. Checklist content:
        1. Regime reassessment (zoom out)
           - Ask: What regime did I think we were in 30 days ago?
           - Ask: What regime are we actually in now?
           - Ask: What evidence changed my confidence?
           - Force: What would have to happen next month for this regime call to be wrong? If you cannot answer, you are anchoring.
        2. Portfolio role clarity (critical at your stage)
           - For each major holding, label: Strategic (years), Cyclical (months-quarters), Tactical (weeks).
           - Check: Is it behaving as expected for its bucket?
           - Check: Am I emotionally treating a tactical position like a strategic one?
           - Check: Am I micromanaging strategic positions with tactical anxiety?
           - Reminder: Most experienced investors lose money by mixing buckets.
        3. Drawdown and stress test (not VaR theater)
           - Ask: What is my real max drawdown if I am wrong on my top 2 themes?
           - Ask: Would that change my lifestyle, board roles, or sleep?
           - Ask: If markets closed for 3 months, would I regret any sizing?
           - Rule: If the answer is yes, size is wrong, not thesis.
        4. Decision journal review (pattern detection)
           - Review the last month's decisions, not P&L.
           - Ask: Where did I follow my rules?
           - Ask: Where did I improvise?
           - Ask: Did improvisation help or hurt?
           - Look for: Confidence-triggered upsizing, delayed exits due to "one more data point", holding because selling felt emotionally premature.
        5. Information diet audit (very important for you)
           - Ask: What inputs actually changed my mind this month?
           - Ask: What inputs just increased conviction without new evidence?
           - Ask: Am I consuming insight or reassurance?
           - Rule: Information that never changes decisions is entertainment, not research.
        6. Capital purpose reminder (age-appropriate, brutally honest)
           - End the review by completing the sentence in writing: "The purpose of my capital at this stage of life is ____________, not ____________."
           - Examples: Independence, not ego. Optionality, not maximum return. Robustness, not brilliance.


- <mark>[ ] [new_features] **[DS-069] Portfolio Invalidation Rule**</mark>
    Why: Portfolio decisions need a clear, explicit invalidation rule with time-bounded review to avoid stale assumptions.
    What: For each portfolio, add a required "Invalidation Rule" text field plus a valid-until date that defaults to 1 month from entry; show an unmistakable expired-state alert when the date passes; when opening a Portfolio page with an expired rule, show a reminder popup that lets the user reset the date to "today" with one button to restart the 1-month counter; add an info (I) hover flyover text explaining the purpose: "Before entry, answer one sentence: \"This trade is wrong if ___ happens.\" If it happens, exit. No debate."

- <mark>[ ] [changes] **[DS-063] Design Issue: Multiple DatabaseManager Instances Across the App**</mark>
    Why: Views and services instantiate their own `DatabaseManager`, leading to multiple SQLite connections, duplicated state, and inconsistent configuration.
    What: Introduce a single shared `DatabaseManager` (DI container or root `EnvironmentObject`), remove direct instantiation in views/services, and pass dependencies explicitly.

- <mark>[ ] [changes] **[DS-064] Design Issue: Duplicated macOS/iOS Data Access Logic**</mark>
    Why: The same queries and models are duplicated in platform-specific `DatabaseManager` extensions, increasing maintenance cost and risk of platform drift.
    What: Extract shared data-access code into a common module used by both macOS and iOS targets, and eliminate duplicated model/query definitions.

- <mark>[ ] [bugs] **[DS-061] Portfolio Risk Drops Options**</mark>
    Why: In portfolios that hold options, the Risk tab ignores them because `PortfolioValuationService.snapshot` only pulls instruments listed in `PortfolioThemeAsset`, while the importer stores options solely in `PositionReports` and never links them into the theme assets table—so options never enter the risk snapshot and are missing from the contributions list.
    What: Include option positions in portfolio risk calculations by sourcing holdings from `PositionReports` (or auto-linking imported options into `PortfolioThemeAsset`) so they appear in the Risk tab with correct value, SRI/liquidity, and weighting; add safeguards to avoid filtering out derivatives or other non-target holdings.

- <mark>[ ] [new_features] **[DS-033] Risk Engine Fallbacks & Flags**</mark>
    Why: Ensure robust risk classification even when data is missing or stale, and surface quality signals to users.
    What: Implement PRIIPs-style volatility fallback bucketing when mapping is missing; mark profiles using fallbacks and expose unmapped/stale flags (`recalc_due_at`, missing inputs) in the Risk Report, Maintenance GUI, and instrument detail; default conservative values when data is absent (e.g., SRI 5, liquidity Restricted).

- <mark>[ ] [changes] **[DS-048] Review Ichimoku Cloud Implementation**</mark>
    Why: Ensure the Ichimoku Cloud indicator matches standard calculations and visuals so signals remain trustworthy.
    What: Audit the Ichimoku computation and plotting (conversion/base lines, leading spans, lagging line, defaults/offsets) against the reference spec, fix any deviations, and document expected behavior plus tests.

## Implemented

- [x] [changes] **[DS-092] Weekly Checklist Dynamic Multi-Line Inputs + Overflow Indicator** (2026-01-05)
    Why: Weekly checklist descriptions need more space and clearer overflow cues so longer notes remain readable without sacrificing compact layouts for short entries.
    What: Replace the targeted weekly checklist text fields with adaptive multi-line inputs that expand up to 15 lines based on content; show a blue overflow indicator when content exceeds the visible area for Regime statement, Original thesis, and Top Macro Risk 1.
    Tested: confirmed by user.

- [x] [changes] **[DS-093] Redesign Historic Performance GUI to Match Reference** (2026-01-06)
    Why: The current Historic Performance view does not match the desired design, so it feels inconsistent with the new visual direction and makes it harder to scan key performance signals.
    What: Redesign the Historic Performance GUI to match the attached reference design, including the header layout (instrument name, large price, delta with percent and timeframe), the segmented time-range control (1D, 5D, 1M, 6M, YTD, 1Y, 5Y, MAX) with the active chip styling, and the chart style (clean grid, muted axis labels, green line with a soft gradient fill). Keep the data and interactions intact while updating typography, spacing, and visual hierarchy to align with the reference.
    Tested: confirmed by user.

- [x] [changes] **[DS-070] DS-062 Cleanup: Remove Remaining DatabaseManager Preference Bindings** (2026-01-04)
    Why: DS-062 split preferences into `AppPreferences`, but a couple of iOS screens still read deprecated `DatabaseManager` prefs. This keeps UI state coupled to the DB manager and blocks full removal of the legacy published fields.
    What: Move the remaining iOS preference bindings from `DatabaseManager` to `AppPreferences`, then remove the deprecated published fields once no call sites remain. Update:
        - `DragonShield iOS/Views/SnapshotGateView.swift`: replace `dbManager.dbVersion` with `preferences.dbVersion` and inject `@EnvironmentObject var preferences: AppPreferences`.
        - `DragonShield iOS/Views/Todos/TodoBoardView.swift`: replace `dbManager.todoBoardFontSize` and `dbManager.$todoBoardFontSize` with `preferences.todoBoardFontSize` and `preferences.$todoBoardFontSize`.
        - Verify any remaining `dbManager.*` preference usage is eliminated (rg for `dbManager.(dbVersion|todoBoardFontSize)`).
        - (Optional) Remove deprecated `@Published` preference fields from `DatabaseManager` once all call sites are migrated.
    Doc: docs/ds-062-database-manager-responsibility-split.md
    Tested: confirmed by user.
- [x] [new_features] **[DS-086] Sidebar Menu Manual Reordering** (2026-01-04)
    Why: Users want to customize the sidebar order to match their workflow without changing the existing category structure.
    What: Allow sidebar menu items to be manually reordered within their current categories; persist the order per user so it survives app restarts; provide a simple reset-to-default action that restores the current default order without changing category groupings.

- [x] [new_features] **[DS-075] Dashboard Trading Profile Field** (2026-01-01)
    Why: Traders need a dedicated, structured Trading Profile GUI to capture identity, regime, alignment, risk, and review memory for governance-first allocation.
    What: Build a desktop-first Trading Profile section (not just a single field) with a left rail for navigation and a persistent top bar for Regime + Risk. The module is read-only by default and focuses on governance, not performance.
        - Global shell: top bar shows "Active Regime" and "Risk State" at all times; left rail tabs: Profile, Regime, Alignment, Strategies, Risk, Rules, Review Log.
        - Profile dashboard: Identity header (profile type, objective, last/next review) and a locked "Profile Coordinates" panel with weighted sliders (read-only; unlock requires explicit review mode).
        - Dominance stack: three lists (What defines me / Secondary modulators / Should not drive decisions) for cognitive anchoring.
        - Regime view: Current regime, confidence, confirming/invalidating signals, and implications.
        - Portfolio alignment view: Table of positions with Regime Fit, Profile Stress, Rule Status; row drill-in shows stressed axes and rule gating.
        - Strategy compatibility view: Fit matrix that explicitly shows blocked strategies with reasons.
        - Risk & early warning view: Behavioral risk monitor with warnings and automatic actions; badge mirrors the top bar.
        - Rules & violations view: Non-negotiable rules plus immutable violation log (no override).
        - Review log: Append-only decisions with event, decision, confidence, and notes.

- [x] [new_features] **[DS-088] Weekly Macro Check: High Priority Portfolios** (2026-01-04)
    Why: Weekly checklist reviews should emphasize the most critical portfolios so they stand out during planning and execution.
    What: Determine the best place to store a per-portfolio "high priority" flag for the Weekly Macro & Portfolio Checklist, document the decision, and implement the required DB migration/model update. Surface the flag in the weekly checklist UI (e.g., badge/visual emphasis or sort/filter) so high-priority portfolios are clearly indicated. Set the flag to "high priority" for these portfolios: RV Crypto Thesis, China AI Tech Portfolio, Avalaor special Investments, I/O Fund AI Technology, Energy.

- [x] [new_features] **[DS-089] Weekly Macro Checklist: Counted Val (CHF) Column** (2026-01-04)
    Why: Users need the same counted valuation reference in the weekly checklist that they already rely on in the Portfolios overview for consistent review context.
    What: In the Weekly Macro & Portfolio Checklist GUI, add a new column "Counted Val (CHF)" and populate it with the same value used in the Portfolios GUI overview.

- [x] [bugs] **[DS-087] Asset Management Report Crypto Orig Currency + Total Crypto Share** (2026-01-04)
    Why: The crypto exposure section reports the "orig. curr" value incorrectly and omits how much crypto contributes to total assets, which can mislead allocation decisions.
    What: In the Asset Management Report (Chapter E), compute the "orig. curr" column from the local value (quantity × price) in the instrument currency instead of showing units; verify the aggregation per crypto; under the "TOTAL CRYPTO" amount, display the crypto total as a percentage of current total assets.

- [x] [bugs] **[DS-071] Price Updates Table Resets Column Widths on Edit** (2026-01-01)
    Why: Entering a value in the "New Price" field rebuilds the table and resets all columns to default widths, forcing manual resizing. This was only relevant to the legacy Price Updates GUI, which has been abandoned.
    What: No change required; the issue is scoped to the legacy UI and is no longer actionable.

- [x] [new_features] **[DS-074] Portfolio Timeline + Time Horizon End Date** (2026-01-01)
    Why: Portfolios need an explicit, standardized time horizon so managers can declare intent and align review timing.
    What: Add a required `timeline_id` on Portfolio that references a new `PortfolioTimelines` table; allow selecting a default timeline when creating/editing a portfolio; add a manual `time_horizon_end_date` field; maintain timeline entries in a separate maintenance table with `description` (text) and `time_indication` (text) fields; display the portfolio time horizon on the same line as the portfolio title, aligned to the right, and editable there; add a DB migration/seed to prefill timeline rows with standard values (e.g., Short-Term: "0-12m", Medium-Term: "1-3y", Long-Term: "3-5y", Strategic: "5y+").
        - GUI: Add a Configuration → Portfolio Timelines maintenance view to add/edit/reorder timelines (description + time indication).
        - GUI: Add Time Horizon picker + End Date toggle/date in Add/Edit Portfolio and in Portfolio Settings.
        - GUI: In the portfolio title bar, show the current time horizon + end date inline (right-aligned) with inline editing.
        - GUI: End date status is color-coded: amber when within 30 days, red when overdue.

- [x] [changes] **[DS-085] Remove Asset Allocation Feature** (2025-12-31)
    Why: Asset Allocation GUI and related workflows are being retired and should be removed to reduce maintenance surface area.
    What: Remove the Asset Allocation GUI and all related functionality; delete code paths, models, services, and assets that are not used elsewhere after removal, ensuring remaining features compile and run without references to Asset Allocation.

- [x] [new_features] **[DS-084] Price Update Manager UX + Unified Update Source** (2025-12-31)
    Why: The current Price Updates GUI mixes auto and manual workflows, shows irrelevant fields (manual "New Price" even when auto is enabled), and splits overlapping concepts ("Auto", "Auto Provider", "Price Source", "Manual Source"), making it hard to scan or update many instruments efficiently.
    What: Keep the existing Price Updates GUI unchanged, and add a new "Next Level Price Update" page that delivers a dense, high-signal experience with filters, sorting, and a coherent update model.
        - Introduce an explicit per-instrument "Update Mode" (Auto or Manual) and a single "Update Source" concept; Auto uses a provider name, Manual uses a user-entered source label. Avoid the overlapping UI fields ("Auto", "Auto Provider", "Price Source", "Manual Source") in the new page in favor of this model.
        - New Next Level table is dense and scannable (compact row height, minimal columns, no redundant fields) and shows as many instruments as possible on one page.
        - Row layout: Instrument, Current Price + Date, Update Mode (chip), Update Source (provider or manual label), Last Update/Status; Manual rows reveal "New Price" + Date inputs, Auto rows hide these inputs and instead show last auto-fetch timestamp/health.
        - Provide filters/tabs: All, Manual, Auto, and Needs Update (stale/missing) with counts; search stays available across all modes.
        - Provide sorting on key columns (Instrument, Current Price, Prices As Of, Update Mode, Last Update/Status) and remember the last sort for the session.
        - Switching a row's Update Mode immediately toggles which inputs are visible and enforces required fields (provider for Auto, source + new price for Manual).
        - Update action applies only to rows with manual inputs; auto rows remain read-only in the update form.

- [x] [bugs] **[DS-082] CHANGELOG Lists Implemented Features as Unreleased** (2025-12-31)
    Why: `CHANGELOG.md` shows items like DS-073 and DS-072 as unreleased even though they are marked Implemented in `new_features.md` and already merged into main, creating confusion about what shipped.
    What: Clarify the source-of-truth for release status (new_features vs changelog vs tags), reconcile DS-072/DS-073 and similar entries, and update the release notes workflow so implemented items appear under the correct release with accurate status.

- [x] [new_features] **[DS-083] Historic Performance Y-Axis Always Visible** (2025-12-31)
    Why: When scrolling the Historic Performance chart horizontally, the y-axis description and scale disappear, making it harder to read values.
    What: Keep the y-axis description and scale pinned/visible while the chart scrolls so users can always read the CHF scale during horizontal navigation.

- [x] [bugs] **[DS-072] Instrument Notes Editor Does Not Open from Instrument Dashboard/Edit** (2025-12-31)
    Why: In the Instrument Dashboard Notes tab and Instrument Edit notes sheet, clicking "Add Note"/"Add Update" or "Open" on an existing note does nothing, so users cannot create or view instrument notes.
    What: Identify the broken presentation path and ensure the note editor sheet opens from all tabs; likely move the `InstrumentNotesView` editor sheets (`showGeneralEditor`, `editingGeneralNote`, `showThemeEditor`) to the top-level view or consolidate into a single `activeEditor` enum so sheet presentation is always attached; keep Add Update disabled unless a theme is selected, but show a clear hint when disabled; verify add/edit works for general notes and theme updates in both Instrument Dashboard and Instrument Edit, with list refresh on save/cancel.

- [x] [changes] **[DS-081] Close Weekly Checklist Window on Mark Complete** (2025-12-31)
    Why: Completing a weekly checklist should return the user to the previous context without requiring an extra close action.
    What: When pressing the "Mark Complete" button in the Weekly Macro & Portfolio Checklist (DS-076), automatically close the checklist window after a successful completion.

- [x] [new_features] **[DS-079] Prefill Thesis Integrity Fields in Weekly Checklist** (2025-12-29)
    Why: Weekly checklist prep should retain stable thesis context across weeks, while still forcing fresh data capture.
    What: When preparing the new weekly checklist report for a portfolio, prefill all entries under section 2 (Thesis integrity check) by copying the existing "Position/Theme" and "Original Thesis (1-2 lines)" fields for each prior entry; leave "New Data This Week" empty for each entry.

- [x] [changes] **[DS-080] Weekly Checklist Exit Button Placement + Styling** (2025-12-29)
    Why: The Exit button should be visually de-emphasized and positioned consistently to reduce accidental clicks while keeping the flow predictable.
    What: In the Weekly Macro & Portfolio Checklist UI, move the Exit button to the right and use a light grey background for the button.

- [x] [changes] **[DS-078] Exempt Portfolios from Weekly Macro & Portfolio Checklist** (2025-12-29)
    Why: Some portfolios (e.g., life insurance) are effectively static and should not be forced into weekly checklist cadence or show as overdue.
    What: Add a per-portfolio "Exempt from weekly checklist" toggle for the Weekly Macro & Portfolio Checklist (DS-076); exempt portfolios are excluded from scheduling, reminders, and overdue counts, and the UI clearly indicates the exempt status with a path to re-enable the checklist.

- [x] [new_features] **[DS-076] Weekly Macro & Portfolio Checklist** (2025-12-28)
    Why: Portfolio reviews need a consistent weekly macro and portfolio discipline to reduce narrative drift, oversizing, and reactive allocation.
    What: Add a weekly checklist workflow per portfolio that runs 15-25 minutes on the same day/time each week and records completion and the written outputs. Before implementation, determine the best UX/UI design for where this lives, how scheduling/reminders work, how responses are captured, and how completion is tracked. The GUI must show when the next check is due, when the last checks were conducted, and provide a history view; include clear guidance text and/or hover tips in the checklist UI. Checklist content:
        1. Regime sanity check (top-down, non-negotiable)
           - Ask in order: Has the macro regime changed or is it noise; Liquidity; Rates (real, not nominal); Policy stance; Risk appetite.
           - Rule: If the regime cannot be articulated in one sentence, you are reacting, not allocating. Capture the one-sentence regime statement.
        2. Thesis integrity check (Bayesian discipline) per major position/theme
           - Capture the original thesis (1-2 lines max).
           - Capture what new data arrived this week.
           - Mark whether the data strengthened, weakened, or left the thesis unchanged.
           - Ask and capture: If I did not already own this, would I still enter it today?
        3. Narrative drift detection
           - Ask: Am I explaining price action with better stories rather than better evidence?
           - Ask: Have I relaxed or redefined my invalidation criteria?
           - Ask: Have I added new reasons to justify an old position?
           - Red flag language to surface: "Longer term...", "The market doesn't understand yet...", "This is actually bullish if you think about it..."
        4. Exposure and sizing check
           - Capture top 3 macro risks right now.
           - Identify which positions express the same risk.
           - Identify hidden correlations.
           - Enforce: No single theme can hurt sleep if wrong; no position grows large only because it went up without re-underwriting.
           - Rule: Upsizing requires fresh confirmation, not comfort.
        5. Action discipline
           - Decide explicitly: Do nothing (most weeks), Trim, Add (only if rule-based), or Exit.
           - Write the decision in one line; no middle ground.

- [x] [bugs] **[DS-073] New News Types Do Not Persist on Existing Notes** (2025-12-28)
    Why: When editing an existing note and selecting a newly added News Type, the selection is not saved; only the legacy/default types persist.
    What: Allow custom News Types (created in News Type settings) to be saved on existing notes by persisting the new type reference and preventing legacy type constraints from blocking updates; verify note updates retain the selected custom type after save and reload.

- [x] [changes] **[DS-068] Fix Release Notes Accuracy and References** (2025-12-25)
    Why: The release notes shown from the sidebar are inaccurate and drift from the source of truth.
    What: Identify the authoritative storage of release note changes (master should be GitHub) and sync it with `new_features.md`; update the release notes display to include the implementation date and the feature reference ID when present (e.g., DS-063).

- [x] [changes] **[DS-062] Design Issue: DatabaseManager Mixing Persistence and UI State** (2025-12-22)
    Why: Database connection logic, domain queries, and UI/table preferences live in the same type, which creates tight coupling and makes testing and maintenance harder.
    What: Split into a focused DB connection/repository layer plus a separate settings/preferences store; move UI table preferences out of `DatabaseManager` and update call sites to use the new services.
    Doc: docs/ds-062-database-manager-responsibility-split.md

- [x] [changes] **[DS-067] Upgrade Historic Performance Graph** (2025-12-25)
    Why: The historic performance chart is hard to inspect over longer periods and doesn’t surface values on hover.
    What: Make the timeline scrollable horizontally, show CHF values on hover for each data point, increase dot size, and make the “today” vertical line bolder.

- [x] [new_features] **[DS-065] Persist Daily Total Portfolio Value History** (2025-12-22)
    Why: Users need to track how the total portfolio value develops over time, which requires a persistent daily history rather than only the latest snapshot.
    What: Store the total portfolio value in the database once per day (one value per day), and add a "Historic Performance" view under Portfolio in the sideview that lists daily CHF totals and shows a simple line chart (x: time, y: CHF).

- [x] [changes] **[DS-066] Add Version Release Notes Popup (Sidebar)** (2025-12-22)
    Why: Users need to review what changed in a release directly from the sidebar, and release notes must be understandable when feature branches are merged.
    What: When clicking the Version entry in the sidebar, open a window that shows all changes for the current release in a table format; during feature-branch merges, ensure each version's change description is written clearly and unambiguously for release notes.

- [x] [changes] **[DS-019] Drop "Order" column in next DB update** (2025-12-20)
    Why: The "Order" attribute is being retired and should be removed from the schema to simplify maintenance. What: In the next database update, add a migration to drop the "Order" column from Instrument Types, update ORM/model definitions and queries to match, and document the schema change in the release notes for the database update.

- [x] [changes] **[DS-025] Drop Order Column from Asset Class Table** (2025-12-20)
    Why: The "Order" column is unused and should be removed to simplify the schema. What: Add a database migration to remove the "Order" column from the Asset Class table and update related models/ORM mappings and queries accordingly.

- [x] [changes] **[DS-060] Shorten To-Do-Tracker Tile** (2025-12-20)
    Why: The To-Do-Tracker tile currently lists every to-do, making the dashboard tile excessively long and hard to scan.
    What: Limit the To-Do-Tracker dashboard tile to show only the top 4 to-dos by default and enable scrolling within the tile to view the remaining items, matching the behavior of the Institutions AUM tile.

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

- [x] [bugs] **[DS-012] Fix Account Price Update Flow** (2026-01-04) From the Dashboard's "accounts need updating" tile, the "latest price" update now persists the latest price with today's date in the instrument prices table and shows a confirmation popup (price + date with an "OK" button) after a successful update that closes upon acknowledgment.
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
