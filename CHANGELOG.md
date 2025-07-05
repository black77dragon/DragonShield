# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
- Replace `account_id` with `institution_id` in `ImportSessions` table
- Fix incorrect parameter label when starting import sessions
- Allow editing Asset Class in Asset SubClass popup
- Restyled Institutions maintenance window for consistent look and feel
- Fix compile error in Institutions view due to missing empty state component
- Added Asset Class maintenance screens with create, update and delete
- Fix compile errors in Asset Class maintenance view on macOS
- Modernize Asset Class add/edit windows with standard design and logging
- Modernize Asset Class list view with search, animations and action bar
- Fix missing modernStatCard helper in Asset Classes view
- Add ZKB position import with progress logging and summary alert
- Fix quantity extraction for ZKB position import and document Excel column mapping
- Parse ticker symbol from Valor and build instrument names including institution and currency
- Default quantity to zero for "ZKB Call Account USD" when cell is blank
- Prompt for instrument details when new securities are imported
- Automatically create ZKB custody and cash accounts when missing and save position reports
- Review each parsed position with editable popup before saving and fix layout constraints
- Provide instrument add dialog with Save/Ignore/Abort when new ISINs are encountered
- Restyle import popups using instrument maintenance window design
- Fix compile errors in position review and import views
- Prompt to delete existing ZKB positions before importing and show count
- Parse value date from ZKB sheets, show import details summary and improve instrument popups
- Correct custody account number detection from cell B6 and extend new instrument prompt with dropdowns
- Fix compile error in instrument prompt view when selecting subclass or currency
- Record ZKB import sessions and link position reports
- Eliminate QoS warnings by presenting modals synchronously
- Condense instrument popups and rename review dialog title
- Show import summary in modern styled popup
- Condense import details popup row spacing
- Default custody positions to "ZKB Custody Account" name
