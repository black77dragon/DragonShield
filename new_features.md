# Project Features and Change Log

This document serves as a central backlog for all pending changes, new features, and maintenance tasks for the DragonShield project. It tracks the lifecycle of features from request to implementation.

**Instructions:**
When adding new features or change requests to the Backlog, please provide a precise and detailed description of the desired change. Include the context ("Why") and acceptance criteria ("What") to ensure clarity.

## Backlog

- [ ] **[DS-001] Fix Instrument Edit Save Button**
    In the "Edit Instrument" GUI, the "Save" button is unresponsive. Specifically, after pressing the button, the window does not close automatically, giving the impression that the action failed.

- [ ] **[DS-002] Harmonize Asset Classes View**
    Upgrade `AssetClassesView.swift` to use the DragonShield Design System (`DSColor`, `DSTypography`, `DSLayout`). Ensure consistent styling for lists, headers, and buttons.

- [ ] **[DS-003] Harmonize Currencies View**
    Upgrade `CurrenciesView.swift` to use the Design System. Focus on table layouts, status badges, and action buttons.

- [ ] **[DS-004] Harmonize Instrument Types View**
    Upgrade `InstrumentTypesView.swift` to use the Design System. Ensure consistency with other configuration views.

- [ ] **[DS-005] Harmonize Institutions View**
    Upgrade `InstitutionsView.swift` to use the Design System. This includes the list of institutions and any detail/edit forms.

- [ ] **[DS-006] Harmonize Price Maintenance View**
    Upgrade `PriceMaintenanceSimplifiedView.swift` to use the Design System. This is a data-heavy view, so focus on readability and table styling.

- [ ] **[DS-007] Harmonize Transaction Types View**
    Upgrade `TransactionTypesView.swift` to use the Design System.

- [ ] **[DS-008] Harmonize Reports Views**
    Review and upgrade `AssetManagementReportView.swift` and `FetchResultsReportView.swift` to ensure generated reports align with the new aesthetic.

- [ ] **[DS-009] Harmonize Data Import/Export**
    Upgrade `DataImportExportView.swift` and `DatabaseManagementView.swift` to use standard Design System components.

## Implemented
- [x] **[DS-010]** Improve contrast in Edit Instrument GUI (change white fields to light grey)
