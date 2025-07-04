# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
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
