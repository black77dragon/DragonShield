# Alerts — Concept & Phased Delivery

## Goals
- Unified alerting for portfolio operations across Instruments, Themes, Asset Classes, Portfolios, and Accounts.
- Cover date-based reminders, price thresholds, and holding-based thresholds (absolute CHF/base and percentage).
- Provide robust maintenance UI (CRUD), overviews (triggered, near), and a timeline for date-related alerts.
- Attach notes and documents to alerts using the existing Attachment infrastructure.

## Scope & Entities
- Scope Types: Instrument, PortfolioTheme, AssetClass, Portfolio, Account.
- Ownership: Not required (no per-user ownership model).
- Tags: Supported via a dedicated Tag table and an Alert↔Tag join table; separate CRUD screen.

## Trigger Types (managed table)
Trigger types are reference data in a dedicated table (`AlertTriggerType`) with CRUD maintenance. Initial types:
- date: fires on or around a date (supports warn-in advance and recurrence in later phases).
- price: fires when latest price crosses above/below a level or exits a band.
- holding_abs: fires when total exposure in scope crosses an absolute threshold in CHF (or base currency).
- holding_pct: fires when the holding share (%) within a portfolio theme crosses a threshold.
- calendar_event: fires around macro/company events with warn-in offsets referencing `EventCalendar` rows.
- macro_indicator_threshold: fires when macro series (CPI, unemployment, PMI) cross configured thresholds.
- news_keyword: fires when tagged news mentions configured keywords/entities.
- volatility: fires when realised vs implied volatility deviates from bounds.
- liquidity: fires when liquidity metrics fall below configured levels.
- scripted: runs user expressions over metrics and fires on true results.
- `requires_date` flag per trigger type toggles whether alerts expose an optional `date` field in the editor (stored in `params_json.date`).

Each alert stores a `params_json` payload with trigger-specific configuration (thresholds, bands, currency_mode, staleness, etc.).

## Core Alert Model
- name, enabled, severity (info | warning | critical)
- subject_type (Instrument | PortfolioTheme | AssetClass | Portfolio | Account | Global | MarketEvent | EconomicSeries | CustomGroup | NotApplicable)
- subject_reference (numeric FK for portfolio contexts, event code for calendar events, or slug/JSON for custom subjects)
- trigger_type_code (FK to `AlertTriggerType.code`)
- params_json (JSON for trigger-specific fields)
- near window: optional proximity definition (pct or abs)
- hysteresis: optional hysteresis (pct or abs) to reduce flip-flopping
- cooldown: optional seconds to suppress repeated events while condition persists
- schedule window: optional start/end window for evaluation (no trading-hours restriction)
- notes: long text; attachments via `AlertAttachment`

## Event & Data Catalogues
- `EventCalendar` captures canonical market events (code, title, category, local date/time, timezone, status, source).
- Macro indicator catalog enumerates economic series accessible to `macro_indicator_threshold` triggers.
- Subject abstraction unifies numeric scopes (Instrument, PortfolioTheme, AssetClass, Portfolio, Account) with logical/global subjects for events and ad-hoc groupings.

## Events & State
- Each time an alert condition is met, an `AlertEvent` row is created with a snapshot of measured values (`measured_json`).
- Event status lifecycle: triggered → acknowledged/snoozed → resolved/expired.
- Muting: `mute_until` on the alert suppresses evaluation until the timestamp.

## FX & Staleness
- Currency handling: parameters can specify `currency_mode` (instrument or base); FX conversion uses current rates.
- Staleness: evaluation can consider staleness of prices and/or FX. If data is stale, alerts can either fire with a flag or be suppressed per configuration (stored in `params_json`).

## Maintenance & Overviews
- CRUD screens: Alerts, Event Calendar, Trigger Types, Tags.
- Overview lists: Triggered (needs attention), Near (within proximity), All (filter/sort by scope, type, severity, tag).
- Timeline: upcoming date-based alerts with warn-in markers.
- Actions: acknowledge, snooze, mute/unmute, enable/disable, bulk edits, and “Evaluate Now”.
- Alert editor date inputs use a popover calendar (defaulting to today) shown on demand; values render in `dd.MM.yy` format and can be cleared.

## UI Additions
- Update alert editor to pick `subject_type`, map numeric subjects, and capture subject references for logical scopes (event codes, custom IDs).
- Event Calendar management view (list/search, quick edit) with import/export pipeline for macro/company schedules.
- Subject-aware dashboards highlighting upcoming events (calendar view) and macro indicators flagged by alerts.
- Lightweight macro series browser to help configure `macro_indicator_threshold` alerts.

## Attachments
- Reuse `Attachment` table and file storage. Alerts link to attachments via `AlertAttachment`.
- Typical use cases: option contracts, research PDFs, broker notices.

## Phases

### Phase 1 — Foundations (this iteration)
- Database schema:
  - `AlertTriggerType` reference table (CRUD-managed).
  - `Alert`, `AlertEvent`, `AlertAttachment` tables.
  - `Tag` and `AlertTag` for labeling.
- Implement severity, near window, hysteresis fields in schema.
- Manual evaluation action (backend function) and basic filters in maintenance UI (CRUD planned next).

### Phase 2 — Power Features
- Composite alerts: AND/OR across conditions.
- Repeated reminders/escalation rules (per severity).
- Snooze/mute/ack flows in UI; event history view.
- Recurrence for date-based alerts (daily/weekly/monthly/quarterly) and warn-in days.
- “Near” classification logic on lists; highlight distance to threshold.

### Phase 3 — Automation & Advanced Triggers
- Event-driven evaluation hooks: price upsert, position recompute.
- Additional triggers: allocation drift vs target, drawdown/change over period, stale data monitors.
- Optional quiet hours; still no real-time streaming needed.
- Backtesting/preview: simulate historical firings for tuning.

## `params_json` Suggestions per Trigger
- date: { date: ISO8601, warn_days: [14,7,1], recurrence: "none|daily|weekly|monthly|quarterly" }
- price: { mode: "cross|outside_band", threshold: 75.0, band_lower: 70.0, band_upper: 80.0, currency_mode: "instrument|base", staleness_days: 3 }
- holding_abs: { threshold_chf: 30000.0, currency_mode: "base" }
- holding_pct: { threshold_pct: 10.0 }
- calendar_event: { event_code: "FOMC-2024-09-18", warn_days: [7,1], auto_close: true }
- macro_indicator_threshold: { series_code: "CPI-US-YOY", mode: "cross", threshold: 3.0 }
- news_keyword: { topics: ["SNB", "inflation"], min_confidence: 0.7 }
- volatility: { metric: "IV30", operator: ">", threshold: 35.0, comparison: "RV20", spread: 10.0 }
- liquidity: { metric: "ADV", operator: "<", threshold: 100000 }
- scripted: { expression: "price.change(5d) < -5 and volume.change(1d) > 30" }
- common: { near_type: "pct|abs", near_value: 2.0, hysteresis_type: "pct|abs", hysteresis_value: 0.5, cooldown_seconds: 86400 }

## Indexing & Performance
- Index alerts by (enabled, trigger_type_code), (scope_type, scope_id), and severity.
- Index events by (alert_id, occurred_at DESC) for fast timelines.
- Keep payloads compact; use TEXT JSON only for parameters and measured snapshots.

## Security & Privacy
- All data remains local; attachments stored under the existing Application Support path.
- No network callbacks or external notifications required; optional macOS local notifications can be added later.
