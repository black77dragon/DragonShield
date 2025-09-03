# DragonShield iOS App — Phase 1 Design

This document describes the Phase 1 iOS app design that reads a read‑only snapshot of the DragonShield SQLite database exported from the macOS app.

## Goals

- Read‑only experience on iPhone (iOS 16+, portrait only)
- Manual, on‑demand data sync via iCloud Drive (Files)
- Clean, native SwiftUI UI consistent with iOS HIG
- Architecture that allows a future upgrade to real‑time sync (CloudKit or LAN API)

## Requirements (Agreed)

- Data sync: read‑only SQLite snapshot (single `.sqlite` file), exported on Mac, imported on iOS via Files/iCloud Drive
- Platforms: iOS 16+, iPhone, portrait only
- Scope: read‑only — Dashboard, Themes (list + detail), Instruments (list + detail), Search, Settings
- UX/UI: native SwiftUI, Swift Charts, SF Symbols, dark/light mode, consistent CHF formatting (apostrophes, 0 decimals for large sums)
- Privacy: single user (Apple ID), unencrypted snapshot acceptable in app sandbox
- Testing: unit tests for import/formatting; manual QA + optional snapshot tests

## High‑Level Architecture

Monorepo with shared code via SPM:

- `DragonShieldCore` (Swift Package)
  - Models, `DatabaseManager`, valuation services, FX conversion, formatters, helpers
  - Platform conditionals for AppKit‑only code
- macOS App (existing)
  - Adds Export Snapshot (Settings → Data Export)
  - Produces single `DragonShield_YYYYMMDD_HHMM.sqlite` via `sqlite3_backup`
- iOS App (new)
  - Import flow via `UIDocumentPicker` (Files → iCloud Drive)
  - Opens DB read‑only with `sqlite3_open_v2(SQLITE_OPEN_READONLY)`
  - SwiftUI tabs: Dashboard | Themes | Instruments | Search | Settings

### Data Flow

1. macOS: user exports snapshot `.sqlite` to iCloud Drive
2. iOS: user opens app → Settings → Import Snapshot → chooses file from iCloud Drive
3. iOS: app copies the file into app sandbox and opens it read‑only
4. UI reads via `DragonShieldCore.DatabaseManager`

### Schema Compatibility

- iOS is read‑only; if snapshot schema is newer than the app, show a friendly warning and block import until app update
- Use `PRAGMA user_version` or existing config table to determine schema version

## Screens (Phase 1)

- Dashboard
  - Total value (CHF), Top Positions, Crypto
  - Tiles consistent with Mac, adapted to iPhone layouts
- Portfolio Themes
  - List: name, status, value
  - Detail: composition (user % distribution chart), notes (read‑only)
- Instruments
  - List + search
  - Detail: latest price, holdings by account, notes (read‑only)
- Search
  - Unified search across instruments, themes, and notes titles
- Settings
  - Import Snapshot, About (version/build), formatting options (if needed)

## UI/UX Notes

- SwiftUI NavigationStack, TabView; Swift Charts for donut/bar charts
- Adaptive, native controls; consistent spacing/typography; dark mode support
- CHF formatting: use shared number formatters (apostrophes, 0 decimals for large sums)

## Security Considerations

- Optional app lock (FaceID) toggle in Settings (Phase 2+)
- Snapshot remains in iOS app sandbox; can be removed from Settings → Manage Data

## Upgrade Paths (Phase 2+)

- CloudKit private DB: full offline sync, conflict resolution for potential edits later
- LAN API (Bonjour): live at home network; lighter lift, LAN‑only
- Both paths are compatible with current core (storage abstraction lives in `DragonShieldCore`)

## Milestones

1. Core extraction (SPM), platform guards, build macOS
2. Snapshot export (done)
3. iOS target + Import flow + basic Dashboard (read‑only)
4. Themes + Instruments (list/detail) + Search
5. Testing + polish (dark mode, formatting, performance)

## Open File Locations

- Export code: `DragonShield/DatabaseManager+Export.swift`
- Export UI: `DragonShield/Views/SettingsView.swift`

