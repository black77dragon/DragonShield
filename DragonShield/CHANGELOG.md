# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each pull request must add a one-line, user-facing entry under **Unreleased** in the appropriate category, including the PR number.

## [Unreleased]


### Added
- DB: Introduce Trade and TradeLeg schema for buy/sell transactions; bump db_version to 4.27 (032, 033) (#PR_NUMBER)
- Add dashboard tile for strict unused instruments (#PR_NUMBER)
- Restructure changelog and archive history (#PR_NUMBER)
- Introduce bank-specific import cards with filename hints and instructions (#PR_NUMBER)
- Allow sorting Composition table by Instrument, Research %, and User % (#PR_NUMBER)
- Copy or export Value Report data from reports (#PR_NUMBER)
- Add repository for strict unused instruments report (#PR_NUMBER)
- Expose strict unused instruments report from Instruments view (#PR_NUMBER)
- Show note icon for institutions with notes in overview table (#PR_NUMBER)
- Persist column widths in Portfolio Themes table (#PR_NUMBER)

### Changed
- Replace status alerts with SwiftUI windows (#PR_NUMBER)
- Replace legacy theme updates list with card-based overview (#PR_NUMBER)
- Enlarge import value report window and enable text copy (#PR_NUMBER)
- Tighten composition table spacing in Portfolio Theme Detail view (#PR_NUMBER)
- Reduce Institution Name column width for better layout (#PR_NUMBER)
- Slim valuation table research and user columns in Portfolio Theme Detail view (#PR_NUMBER)
- Enlarge Portfolio Theme Detail window to fit valuation columns (#PR_NUMBER)
- Use shared DashboardTileLayout for compact dashboard list tiles (#PR_NUMBER)
- Adjust Portfolio Themes list column widths and date display (#PR_NUMBER)

### Fixed

- Resolve ambiguous purgePositionReports overload causing build errors (#PR_NUMBER)
- Ensure unused instruments query considers all historical positions (#PR_NUMBER)
- Update deprecated APIs for macOS 14 compatibility (#PR_NUMBER)

### Removed
- Remove Health Checks from sidebar (#PR_NUMBER)
- Remove redundant Portfolio Theme Overview tab and associated view (#PR_NUMBER)
- Remove default timezone setting and base currency placeholder from Settings (#PR_NUMBER)
- Remove obsolete feature flag 'Enable Attachments for Theme Updates'; attachments now always enabled (#PR_NUMBER)
- Remove debug-only force database overwrite setting (#PR_NUMBER)
- Remove auto FX update configuration and settings toggle (#PR_NUMBER)

### Security

## [4.7.0] - 2025-09-09

## [4.7.1] - 20 20 12 61 79 80 81 98 701 33 100 204 250 395 398 399 400date +%Y-%m-%d)

### Added
- Transactions Phase 1 (buy/sell): Trade + TradeLeg schema (dbmate migrations 032/033), new Transactions UI (history + CRUD), detailed validation and logging. Balances in the form read snapshots (PositionReports); trades do NOT update snapshots (P&L only).


### Changed
- Portfolio Theme handling tightened: edits are blocked when a theme is archived or soft-deleted (database guards across theme meta, holdings, and updates) (#1048)
- Standardized error messaging when attempting edits on locked themes: "no changes possible, restore theme first" (#1048)
- Theme Workspace → Settings: improved readability with white backgrounds for editable text fields and dropdowns; Name input right-aligned and bold; header canvas right-aligned for clearer emphasis (#1048)
- Theme Workspace → Danger Zone: restructured into separate lines with toggles for "Soft Deleted" and "Archived Theme", plus a standalone "Full Restore" button (#1048)
- Theme Updates UI: disallow creating/ editing updates when the parent theme is soft-deleted (previously only archived was blocked) (#1048)

### Removed
- Portfolio Themes list: removed "New Update" and "Edit Theme" actions to simplify the flow; create updates from within the Theme Workspace instead (#1048)

## [4.6.0] - 2025-06-15

### Added
- Schema history and test data.

### Changed
- Renamed positions.

### Fixed
- None.

### Removed
- None.

### Security
- None.

Historical entries prior to this release have been moved to `Archive/CHANGELOG-ARCHIVE.md`.
