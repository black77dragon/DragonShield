# DS-062: Split DatabaseManager Responsibilities (Connection, Data Access, UI Preferences)

## 1. Problem
DatabaseManager currently owns the SQLite connection, exposes domain data access, and stores UI/configuration state via @Published properties. The configuration loader in `DatabaseManager+Configuration.swift` writes directly into the same object that performs queries and owns the connection. This creates tight coupling between persistence, configuration, and UI state.

Symptoms in the current codebase:
- `DatabaseManager.swift` holds the SQLite connection and a long list of `@Published` UI/config values.
- `DatabaseManager+Configuration.swift` loads UI/table preferences into `DatabaseManager` itself.
- iOS/macOS call sites depend on `DatabaseManager` for both data access and UI preference state, binding UI lifecycle to DB lifecycle.

Impact (moderate day-to-day, high long-term):
- Single Responsibility violation: persistence, configuration, and UI preferences all live in one class, so every consumer gets more than it needs.
- Implicit global state: UI binds to DB lifecycle; changes to preferences can trigger DB-side changes and vice versa.
- Testability drag: config/UI tests require a DB; DB tests inherit UI defaults/side effects.
- Evolution risk: new preferences or queries touch the same central object, increasing coupling and merge conflicts.

## 2. Target State
A small set of focused objects with clear responsibilities:

- DatabaseConnection
  - Owns SQLite open/close and lifecycle.
  - Provides a handle (`OpaquePointer?`) to repositories/stores.
  - Supports read-only snapshot opening for iOS.

- DatabaseRepository (or per-domain repositories)
  - Exposes domain data access methods currently in `DatabaseManager+*.swift`.
  - Uses `DatabaseConnection` for SQLite access.
  - Stateless or minimally stateful; no UI bindings.

- ConfigurationStore
  - Loads and writes configuration values from the `Configuration` table.
  - Returns typed configuration models instead of mutating UI state.

- AppPreferences (ObservableObject)
  - Holds UI preferences and other UI-facing config state as `@Published` values.
  - Hydrates from ConfigurationStore and persists changes via explicit save methods.
  - Used by views instead of `DatabaseManager` directly.

- DatabaseManager (temporary facade)
  - Thin wrapper to preserve call sites during migration.
  - Delegates to DatabaseConnection, repositories, and AppPreferences.
  - Eventually removable once call sites migrate.

## 3. Solution Design

Key design choices:
- Split connection management from data access logic. Repositories accept a `DatabaseConnection` (or protocol) instead of a monolithic manager.
- Move configuration loading out of `DatabaseManager`. Replace `loadConfiguration()` side effects with `ConfigurationStore.load()` returning a typed configuration model.
- Put UI preferences into `AppPreferences` and bind UI to that object, not the DB.
- Keep a temporary facade in `DatabaseManager` to avoid a big-bang migration; it forwards calls and exposes compatibility properties where needed.

Proposed types and responsibilities:
- `DatabaseConnection`:
  - `open(readOnly: Bool, path: String?)`, `close()`, `reopen()`, `hasOpenConnection`.
  - Houses db file metadata and error reporting.

- `ConfigurationStore`:
  - `load() -> ConfigurationSnapshot` (struct with typed values).
  - `update(key:value:)`, `upsert(key:value:dataType:)` for persistence.
  - No `@Published` state; no UI dependencies.

- `AppPreferences`:
  - `@Published` properties for all UI/table preferences and other UI-facing config.
  - `apply(_ snapshot: ConfigurationSnapshot)` and `persist(...)` helpers.

- `DatabaseRepository` (or grouped repositories by domain):
  - Existing extensions (`DatabaseManager+Instruments.swift`, etc.) move here over time.
  - Each repository accepts a `DatabaseConnection` reference.

## 4. Migration Plan (Low Risk, Staged)

### 4.1 Phase 0: Inventory and map call sites (no behavior changes)
Status: completed 2025-12-20.
1. List all `@Published` config fields and which views bind to them.
2. Identify where `DatabaseManager.loadConfiguration()` is called and which properties are relied upon.
3. Identify iOS vs macOS usage (macOS authoring environment vs iOS read-only snapshots).

### 4.2 Phase 1: Introduce new types behind DatabaseManager (no call-site changes)
Status: completed 2025-12-20.
1. Add `DatabaseConnection` and move open/close logic into it (DatabaseManager delegates internally).
2. Add `ConfigurationStore` that reads/writes the Configuration table using `DatabaseConnection`.
3. Add `AppPreferences` (ObservableObject) and implement `apply(ConfigurationSnapshot)`.
4. Update `DatabaseManager.loadConfiguration()` to call `ConfigurationStore.load()` and apply to `AppPreferences`, while still mirroring existing `@Published` properties for compatibility.

### 4.3 Phase 2: Shift UI bindings to AppPreferences
1. Update SwiftUI views to observe `AppPreferences` instead of `DatabaseManager` for configuration and table preferences.
2. For each UI preference update method (e.g., `setAccountsTableFontSize`), route changes to `AppPreferences` and persist via `ConfigurationStore`.

### 4.3.1 Phase 2 Migration Order (Staged)
1. Plumb `AppPreferences` into the environment at app roots (macOS + iOS). Status: completed 2025-12-20.
2. Settings + Application Startup screens (lowest risk, direct prefs). Status: completed 2025-12-20.
3. Maintenance tables via `TablePreferences` + `ResizableTableViewModel` (centralized). Status: completed 2025-12-20.
4. Low-usage fields (`defaultTimeZone`, `includeDirectRealEstate`, `directRealEstateTargetCHF`). Status: completed 2025-12-20.
5. High-usage fields last (`baseCurrency`, `asOfDate`, `decimalPrecision`). Status: completed 2025-12-20.

### 4.3.2 Phase 2 Step 3 Verification Checklist
Status: completed 2025-12-20.
1. Open a maintenance table (e.g., Institutions or Accounts).
2. Change column widths and font size.
3. Close and reopen the view (or restart the app).
4. Confirm widths and font size persist.
5. Use "Reset View" and confirm defaults are restored.

### 4.3.3 Phase 2 Step 4 Verification Checklist
Status: completed 2025-12-20.
1. Open Price Maintenance and confirm timestamps render with the configured time zone.
2. Open Price History and confirm date formatting matches the configured time zone.
3. Open Portfolio Theme Updates and change the date filter; confirm results align with the time zone.
4. Open Target Allocation and confirm the direct real estate toggle/amount reflect stored config.

### 4.3.4 Phase 2 Step 5 Verification Checklist
Status: completed 2025-12-20.
1. Change base currency in Settings and confirm dashboards/reports update labels and values.
2. Change the report as-of date and confirm Exchange Rates and Reports reflect the selected date.
3. Change decimal precision and confirm numeric formatting updates in iOS Instruments list.
4. Restart the app and confirm base currency, as-of date, and precision persist.
5. Open iOS Dashboard and macOS Dashboard to confirm both read from `AppPreferences`.

### 4.4 Phase 3: Move data access into repositories
Scope (covered by Steps 1-10 below):
- Create a `DatabaseRepository` (or per-domain repositories) that use `DatabaseConnection`.
- Move a small, well-scoped extension (e.g., `DatabaseManager+Configuration` or a single read-only domain) to the repository and update the facade to forward calls.
- Repeat domain-by-domain, updating call sites to use repositories directly where feasible.

### 4.4.1 Phase 3 Step 1: Extract NewsType Repository
Status: completed 2025-12-20.
1. Move NewsType queries/mutations into `NewsTypeRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+NewsType` to delegate to the repository.
3. Keep existing call sites working via facade methods and repository initializers.

### 4.4.2 Phase 3 Step 1 Verification Checklist
Status: completed 2025-12-20.
1. Open News Type Settings and confirm the list loads.
2. Create a new News Type and verify it appears in the list.
3. Edit an existing News Type and verify the changes persist.
4. Reorder News Types and confirm the new order is saved.
5. Disable a News Type and confirm it disappears from the active list.

### 4.4.3 Phase 3 Step 2: Extract AlertTriggerType Repository
Status: completed 2025-12-20.
1. Move AlertTriggerType queries/mutations into `AlertTriggerTypeRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+AlertTriggerType` to delegate to the repository.
3. Preserve the `requires_date` compatibility handling in list queries.

### 4.4.4 Phase 3 Step 2 Verification Checklist
Status: completed 2025-12-20.
1. Open Alert Trigger Type Settings and confirm the list loads.
2. Create a new trigger type and confirm it appears in the list.
3. Edit an existing trigger type and confirm changes persist.
4. Reorder trigger types and confirm the order is saved.
5. Deactivate and restore a trigger type and confirm status changes persist.

### 4.4.5 Phase 3 Step 3: Extract Tag Repository
Status: completed 2025-12-20.
1. Move Tag queries/mutations into `TagRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+Tag` to delegate to the repository.
3. Preserve existing call sites via the facade.

### 4.4.6 Phase 3 Step 3 Verification Checklist
Status: completed 2025-12-20.
1. Open Tag Settings and confirm the list loads.
2. Create a new Tag and verify it appears in the list.
3. Edit an existing Tag and confirm changes persist.
4. Reorder Tags via drag handles and confirm the new order persists.
5. Deactivate and restore a Tag and confirm status changes persist.

### 4.4.7 Phase 3 Step 4: Extract TransactionTypes Repository
Status: completed 2025-12-20.
1. Move TransactionTypes queries/mutations into `TransactionTypeRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+TransactionTypes` to delegate to the repository.
3. Preserve existing call sites via the facade.

### 4.4.8 Phase 3 Step 4 Verification Checklist
Status: completed 2025-12-20.
1. Open Transaction Types and confirm the list loads.
2. Create a new Transaction Type and verify it appears in the list.
3. Edit an existing Transaction Type and confirm changes persist.
4. Delete a Transaction Type (if not referenced) and confirm it is removed.
5. Adjust Sort Order and confirm it normalizes and persists.

### 4.4.9 Phase 3 Step 5: Extract InstrumentPriceSource Repository
Status: completed 2025-12-20.
1. Move InstrumentPriceSource queries/mutations into `InstrumentPriceSourceRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+InstrumentPriceSource` to delegate to the repository.
3. Keep `enabledPriceSourceRecords` filtering via active instruments passed in from the facade.

### 4.4.10 Phase 3 Step 5 Verification Checklist
Status: completed 2025-12-20.
1. Open Price Maintenance and confirm existing price source rows load.
2. Toggle enabled state and confirm it persists after reload.
3. Edit provider/external ID and confirm it persists after reload.
4. Trigger a price fetch and confirm only enabled, valid sources are used.
5. Verify status updates (`last_status` / `last_checked_at`) change after a fetch.

### 4.4.11 Phase 3 Step 6: Extract PortfolioThemeStatus Repository
Status: completed 2025-12-20.
1. Move PortfolioThemeStatus queries/mutations into `PortfolioThemeStatusRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+PortfolioThemeStatus` to delegate to the repository.
3. Preserve ThemeStatusDBError mapping and default status enforcement.

### 4.4.12 Phase 3 Step 7: Extract InstrumentPrice Repository
Status: completed 2025-12-20.
1. Move InstrumentPrice queries/mutations into `InstrumentPriceRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+InstrumentPrice` to delegate to the repository.
3. Preserve SwiftUI refresh behavior after price upserts.

### 4.4.13 Phase 3 Step 8: Extract Currency Repository
Status: completed 2025-12-20.
1. Move currency queries/mutations into `CurrencyRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+Currencies` to delegate to the repository.
3. Preserve existing ordering and debug output behavior.

### 4.4.14 Phase 3 Step 8 Verification Checklist
Status: completed 2025-12-20.
1. Open the Currencies screen and confirm the list loads with the expected ordering.
2. Add a new currency and verify it appears in the list.
3. Edit a currency (name/symbol/flags) and confirm changes persist after reload.
4. Deactivate a currency and verify it no longer appears in the active list.
5. Run the debug currency listing (if used) and confirm output is unchanged.

### 4.4.15 Phase 3 Step 9: Extract InstrumentNote Repository
Status: completed 2025-12-20.
1. Move InstrumentNote queries/mutations into `InstrumentNoteRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+InstrumentNotes` to delegate to the repository.
3. Preserve creation logging and mention filtering behavior.

### 4.4.16 Phase 3 Step 9 Verification Checklist
Status: completed 2025-12-22.
1. Open Instrument Notes for an instrument and confirm general notes and updates load.
2. Create a new instrument note and confirm it appears with the correct type and author.
3. Pin/unpin a note and confirm the list order updates with pinned-first ordering.
4. Open theme mentions and confirm mention filtering still matches code/name tokens.
5. Verify the notes summary (updates/mentions counts) matches the visible lists.

### 4.4.17 Phase 3 Step 10: Extract PortfolioThemeUpdate Repository
Status: completed 2025-12-22.
1. Move PortfolioThemeUpdate queries/mutations into `PortfolioThemeUpdateRepository` with `DatabaseConnection`.
2. Update `DatabaseManager+PortfolioThemeUpdates` to delegate to the repository.
3. Preserve logging, pinned ordering, and soft-delete behaviors.

### 4.4.18 Phase 3 Step 10 Verification Checklist
Status: completed 2025-12-22.
1. Open a Portfolio Theme Updates view and confirm active updates list loads with pinned-first order.
2. Create a new update and confirm it appears with the correct type and author.
3. Edit an update and confirm updated content and timestamps persist.
4. Soft-delete an update and confirm it moves to the deleted view.
5. Restore and permanently delete an update and confirm both behaviors work.
6. Confirm older updates (outside the last 30 days) still appear with Date set to All by default.

### 4.5 Phase 4: Slim the facade and remove duplicated state
1. Deprecate `DatabaseManager` `@Published` config fields once all UI binds to `AppPreferences`.
2. Remove configuration mutation from `DatabaseManager` and delete compatibility shims.
3. Evaluate removing `DatabaseManager` entirely or keep it as a lightweight composition root.

### 4.5.1 Phase 4 Step 1: Deprecate DatabaseManager @Published preferences
Status: completed 2025-12-22.
1. Mark `DatabaseManager` preference-style `@Published` fields as deprecated.
2. Point callers to `AppPreferences` equivalents in deprecation messages.
3. Leave DB metadata and transient UI state on `DatabaseManager` unchanged.

### 4.5.2 Phase 4 Step 1 Verification Checklist
1. Build the app and confirm deprecation warnings appear (no errors).
2. Open Settings and confirm preference reads/writes still work.
3. Open a maintenance table and confirm font size/column widths persist.
4. Launch the iOS snapshot flow and confirm snapshot settings still load.

### 4.5.3 Phase 4 Step 2: Remove configuration mutation from DatabaseManager
Status: completed 2025-12-22.
1. Replace `DatabaseManager.updateConfiguration` / `upsertConfiguration` usage with `ConfigurationStore`.
2. Update table preference setters to update `AppPreferences` directly and persist via `ConfigurationStore`.
3. Remove the compatibility shims for configuration mutation from `DatabaseManager`.

### 4.5.4 Phase 4 Step 2 Verification Checklist
Status: completed 2025-12-22.
1. Toggle FX auto-update and iOS snapshot auto-export and confirm persistence after restart.
2. Adjust maintenance table font size/column widths and confirm preferences remain in sync across views.
3. Save target allocation settings and confirm direct real estate settings persist.
4. Save Ichimoku settings and confirm they load correctly on next open.

### 4.5.5 Phase 4 Step 3: Decide on DatabaseManager facade scope
Decision: keep a thin `DatabaseManager` facade (Option A). Status: decided 2025-12-22.
1. Keep `DatabaseManager` as a lightweight composition root for `DatabaseConnection`, `ConfigurationStore`, and `AppPreferences`.
2. Limit its public API to coordination helpers and repository forwarding, avoiding new preference/data mutations.
3. Revisit full removal only if/when call-site wiring cost is justified.

## 5. Phase 0 Inventory (Completed 2025-12-20)
Phase 0 completed.

### 5.1 @Published config fields and bindings

- Base currency and precision (`baseCurrency`, `decimalPrecision`)
  - macOS views: `DragonShield/Views/PortfolioThemeWorkspaceView.swift`, `DragonShield/Views/AssetManagementReportView.swift`, `DragonShield/Views/RiskReportView.swift`, `DragonShield/Views/ExchangeRatesView.swift`, `DragonShield/Views/NewDashboardView.swift`
  - iOS views: `DragonShield iOS/Views/Dashboard/IOSDashboardView.swift`, `DragonShield iOS/Views/Instruments/InstrumentsListView.swift`, `DragonShield iOS/Views/Risk/RiskReportIOSView.swift`, `DragonShield iOS/Views/Reports/AssetManagementReportView.swift`, `DragonShield iOS/Views/Search/SearchView.swift`
  - services/view models/tests: `DragonShield/PortfolioValuationService.swift`, `DragonShield/ViewModels/AssetManagementReportViewModel.swift`, `DragonShield/ViewModels/DashboardRiskTilesViewModel.swift`, `DragonShieldTests/ThemeValuationFxParityTests.swift`

- Report as-of date (`asOfDate`)
  - macOS: `DragonShield/Views/ExchangeRatesView.swift`, `DragonShield/ViewModels/ExchangeRatesViewModel.swift`, `DragonShield/ViewModels/AssetManagementReportViewModel.swift`
  - iOS: `DragonShield iOS/Views/Reports/AssetManagementReportView.swift`, `DragonShield iOS/Views/Reports/ReportsMenuView.swift`

- Time zone (`defaultTimeZone`)
  - macOS: `DragonShield/Views/PriceMaintenanceSimplifiedView.swift`, `DragonShield/Views/PriceHistoryView.swift`, `DragonShield/Views/PortfolioThemeUpdatesView.swift`

- Direct real estate config (`includeDirectRealEstate`, `directRealEstateTargetCHF`)
  - macOS: `DragonShield/ViewModels/TargetAllocationViewModel.swift`

- FX auto-update preferences (`fxAutoUpdateEnabled`, `fxUpdateFrequency`)
  - macOS: `DragonShield/Views/SettingsView.swift`, `DragonShield/Views/ApplicationStartupView.swift`
  - core/app: `DragonShield/Core/Health/FXStatusHealthCheck.swift`, `DragonShield/DragonShieldApp.swift`

- iOS snapshot export preferences (`iosSnapshotAutoEnabled`, `iosSnapshotFrequency`, `iosSnapshotTargetPath`, `iosSnapshotTargetBookmark`)
  - macOS: `DragonShield/Views/SettingsView.swift`, `DragonShield/Views/ApplicationStartupView.swift`
  - services: `DragonShield/Services/IOSSnapshotExportService.swift`

- DB metadata (`dbMode`, `dbFilePath`, `dbFileSize`, `dbCreated`, `dbModified`, `dbVersion`)
  - macOS: `DragonShield/Views/DatabaseManagementView.swift`, `DragonShield/Views/ModeBadge.swift`
  - iOS: `DragonShield iOS/Views/Settings/IOSSettingsView.swift`, `DragonShield iOS/Views/SnapshotGateView.swift`, `DragonShield iOS/Views/Dashboard/IOSDashboardView.swift`, `DragonShield iOS/Views/RootTabView.swift`
  - services/app: `DragonShield/BackupService.swift`, `DragonShield/DragonShieldApp.swift`

- Table preferences (font size + column fractions)
  - Fields: `institutionsTableFontSize`, `institutionsTableColumnFractions`, `instrumentsTableFontSize`, `instrumentsTableColumnFractions`, `assetSubClassesTableFontSize`, `assetSubClassesTableColumnFractions`, `assetClassesTableFontSize`, `assetClassesTableColumnFractions`, `currenciesTableFontSize`, `currenciesTableColumnFractions`, `accountsTableFontSize`, `accountsTableColumnFractions`, `positionsTableFontSize`, `positionsTableColumnFractions`, `portfolioThemesTableFontSize`, `portfolioThemesTableColumnFractions`, `transactionTypesTableFontSize`, `transactionTypesTableColumnFractions`, `accountTypesTableFontSize`, `accountTypesTableColumnFractions`
  - Access path: `DragonShield/helpers/TablePreferences.swift` + `DragonShield/Views/Components/MaintenanceTable/ResizableTableViewModel.swift`
  - macOS views that bind/restore prefs: `DragonShield/Views/PortfolioView.swift`, `DragonShield/Views/InstitutionsView.swift`, `DragonShield/Views/AccountTypesView.swift`, `DragonShield/Views/InstrumentTypesView.swift`, `DragonShield/Views/AssetClassesView.swift`, `DragonShield/Views/AccountsView.swift`, `DragonShield/Views/TransactionTypesView.swift`, `DragonShield/Views/NewPortfoliosView.swift`, `DragonShield/Views/PositionsView.swift`, `DragonShield/Views/CurrenciesView.swift`, `DragonShield/Views/TradesHistoryView.swift`, `DragonShield/Views/PortfolioThemesAlignedView.swift`

- Todo board font (`todoBoardFontSize`)
  - macOS: `DragonShield/Views/DashboardTiles/TodoDashboardTile.swift`, `DragonShield/Views/SidebarView.swift`
  - iOS: `DragonShield iOS/Views/Todos/TodoBoardView.swift`

- Trade error status (`lastTradeErrorMessage`)
  - macOS: `DragonShield/Views/TradeFormView.swift`

### 5.2 loadConfiguration call sites

- `DragonShield/DatabaseManager.swift` in `init()`, `openReadOnly(at:)`, `reopenDatabase()`
- `DragonShield/DatabaseManager+Configuration.swift` in `updateConfiguration`, `upsertConfiguration`, `forceReloadData`
- `DragonShield/BackupService.swift` after restore/metadata refresh

### 5.3 iOS vs macOS usage snapshot

- iOS-only references: `decimalPrecision`, iOS DB metadata displays (`dbCreated`, `dbModified`, `dbVersion` in snapshot gate/settings), iOS dashboard uses `dbFilePath`.
- macOS-only references: `defaultTimeZone`, `includeDirectRealEstate`, `directRealEstateTargetCHF`, `fxAutoUpdateEnabled`, `fxUpdateFrequency`, `iosSnapshot*` preferences, `lastTradeErrorMessage`, all table preference bindings (Maintenance tables).
- Shared: `baseCurrency`, `asOfDate`, `dbFilePath`, `todoBoardFontSize` are used across both platforms.

## 6. Testing and Safety Checks

- Add unit tests for `ConfigurationStore.load()` using a fixture DB or in-memory SQLite.
- Add tests for `AppPreferences.apply(snapshot:)` to ensure typed decoding is correct.
- Add a small integration test that loads config -> applies preferences -> persists a change and reloads.
- Validate iOS snapshot open paths still read configuration without triggering schema mutations.

## 7. Rollout Notes

- Keep behavior identical until Phase 2; this avoids UI regressions.
- Prefer small PRs: move one configuration group or one repository at a time.
- Track each `@Published` removal in a checklist to avoid orphaned UI bindings.

## 8. Definition of Done

- UI preferences are owned by `AppPreferences`, not `DatabaseManager`.
- Configuration read/write is isolated in `ConfigurationStore`.
- Data access code lives in repositories that use `DatabaseConnection`.
- `DatabaseManager` is either removed or a thin facade with no UI state.
