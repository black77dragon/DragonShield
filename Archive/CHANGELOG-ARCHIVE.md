# Changelog Archive

Historical changelog entries for non-v1 releases are archived here.

## [2025.10.18-rollback] - 2025-10-18

### Notes
- Restored Pre-PR #1065 codebase with working account views.
- Reinstated date/price formatting helpers, editable account positions, and refresh UI state.
- Removed all changes introduced after PR #1064 (iOS target restructure, new docs/tests, refresh logging revamp, etc.).

## [4.7.2] - 2025-09-18

### Notes
- adopt sheet-based floating search pickers across dashboards, alerts, and trade forms
- add the new Ichimoku Dragon services, views, and data resources
- refresh supporting screens, settings, and docs to align with the new workflows
- @black77dragon

## [4.7.1] - 2025-09-13

## [4.7.0] - 2025-09-09

### Notes
- Portfolio Theme handling tightened: edits are blocked when a theme is archived or soft-deleted (database guards across theme meta, holdings, and updates) (#1048)
- Standardized error messaging when attempting edits on locked themes: "no changes possible, restore theme first" (#1048)
- Theme Workspace → Settings: improved readability with white backgrounds for editable text fields and dropdowns; Name input right-aligned and bold; header canvas right-aligned for clearer emphasis (#1048)
- Theme Workspace → Danger Zone: restructured into separate lines with toggles for "Soft Deleted" and "Archived Theme", plus a standalone "Full Restore" button (#1048)
- Theme Updates UI: disallow creating/ editing updates when the parent theme is soft-deleted (previously only archived was blocked) (#1048)
- Portfolio Themes list: removed "New Update" and "Edit Theme" actions to simplify the flow; create updates from within the Theme Workspace instead (#1048)
- PR: https://github.com/black77dragon/DragonShield/pull/1048
- Tag: v4.7.0

## [1.7.0-ios] - 2025-09-05

### Notes
- v1.7.0‑iOS — Instrument Valuation, Dashboard Tiles, Theme Holdings, Privacy Blur
- Highlights
- Instrument detail (iOS): total position, total value (CHF using latest price + FX), per‑account breakdown, “positions as of” label, and graceful handling of missing price/FX.
- FX robustness: case‑insensitive currency lookup and fallback to latest‑by‑date when is_latest isn’t set.
- Theme detail (iOS): holdings table (instrument, qty, CHF value) with latest price + FX; sorted by CHF.
- Dashboard (iOS): tiles for Total Value, Missing Prices, Crypto Allocations, and Portfolio by Currency; large‑number formatting.
- Settings (iOS): toggles to show/hide dashboard tiles and a Privacy toggle to blur CHF values (strong blur).
- First‑run experience (iOS): snapshot gate shows current DB snapshot info and lets you import immediately.
- Navigation: jump from Instrument → Theme detail via memberships list.
- New (iOS)
- Instrument Detail:
- Total position (aggregated), Total Value (CHF), per‑account CHF values
- Handles missing price/FX with “—” and small badges
- FX:
- Case‑insensitive currency match
- Fallback to latest rate by date when is_latest is missing
- Themes:
- Theme holdings table (qty + CHF) computed via latest price + FX
- Empty‑state hint if snapshot lacks required tables
- Dashboard:
- Total Asset Value, Missing Prices, Crypto Allocations, Portfolio by Currency
- Settings → Dashboard Tiles to toggle visibility
- Privacy:
- Settings → Privacy → “Blur values (CHF)”; applies a strong blur to tile/value displays
- Snapshot Gate:
- On first launch (or no DB loaded), shows DB info and Import Snapshot
- Stability & Compatibility
- Uses safe position fetching on iOS; if PositionReports or related tables are missing, tiles render empty without errors.
- PortfolioTheme fetching adapts to snapshots that lack newer columns/tables; provides helpful empty‑state guidance.
- Tips
- If Themes or totals are empty, import a full snapshot via Settings → Import Snapshot.
- Configure dashboard tiles and privacy blur in Settings → Dashboard Tiles / Privacy.
- Known Limitations
- Snapshots without PositionReports will show 0/empty totals and empty crypto/currency tiles.
- Snapshots without PortfolioTheme/PortfolioThemeAsset will show an empty Themes tab with guidance to import a full snapshot.

## [4.11] - 2025-09-02

## [4.10] - 2025-08-30

## [4.9] - 2025-08-28

## [4.8] - 2025-08-26

## [4.7] - 2025-08-24

### Notes
- *DragonShield — Release Notes (last 3 days)**
- **Theme Updates overhaul (Steps 6A–6C)**
- New Updates experience inside Theme Details: create, view, edit, pin/unpin, and delete notes.
- Clean timestamp format (`yyyy-MM-dd HH:mm`) and selectable rows with bottom action bar.
- Expand/collapse behavior with full markdown rendering; no duplicate first-line preview.
- **Instrument ↔ Theme updates integration (Steps 7A–7C)**
- From an Instrument you can open all linked updates and mentions across themes.
- Simplified UI: “Open Instrument Notes” button; unnecessary duplicate tables removed.
- **Attachments for Theme Updates (8A–8B)**
- Add files to updates; content-addressed storage (SHA-256) with de-duplication.
- File extensions preserved; Quick Look / Reveal supported.
- Safe removal: prompts to unlink and fully delete file + empty folder cleanup.
- **New:** URL attachments supported (open in browser).
- **Portfolio Theme Details polish**
- Modern modal layout with clearer Overview/Composition/Valuation/Updates tabs.
- Alignment and spacing fixes; better readability of long notes and attachment chips.
- **Stability & correctness**
- More reliable FX conversion in Theme Valuation (uses latest `ExchangeRates`).
- General performance and UI responsiveness improvements.

## [4.6.0] - 2025-08-19

### Notes
- Highlights
- Configurable startup health checks
- Introduced a registry and runner for pluggable diagnostics, plus a dedicated UI that summarizes results and highlights warnings or errors
- Asset‑allocation validation overhaul
- Validation status now stays in sync for class and subclass targets, including a “zero‑target” skip rule to purge irrelevant findings and enforce compliance status
- Positions view search
- Added a search bar to filter positions across all fields, with quick clearing and inline magnifier icon
- Safer backup & restore workflow
- Expanded logs, added instrument validation tools, and ensured reference data coverage during backups, improving overall reliability
- Miscellaneous
- Documentation and parser mapping updates keep specs current and clarify integration guidelines
- README reflects current vision and version history, reinforcing local‑first, encrypted storage principles
- Testing
- No tests were executed. (not requested)
- Notes
- None.
