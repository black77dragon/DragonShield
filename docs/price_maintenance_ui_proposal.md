# Price Maintenance Window — Proposal

## Goals

- Provide a fast, reliable screen to view, filter, sort, and update latest prices for all instruments.
- Support inline edits, batch updates, validation, and keyboard-driven workflows.
- Clearly surface missing or stale prices and make them easy to fix.

## Core UI

- Location: new view `PriceMaintenanceView` (menu/Sidebar: “Price Maintenance”).
- Main area: table/grid with the following columns:
  - Instrument: name (+ ticker/ISIN/valor in smaller secondary text).
  - Currency: instrument currency.
  - Latest Price: from `InstrumentPriceLatest` (read-only cell).
  - As Of: from `InstrumentPriceLatest` (read-only cell).
  - Source: from `InstrumentPriceLatest` (read-only cell).
  - New Price: inline editable numeric field per row.
  - New As Of: date picker per row (defaults to today when editing).
  - New Source: inline text or dropdown (e.g., manual, vendor id).
  - Actions: Save (per row) + Revert.

## Filters

- Text search: name, ticker, ISIN, valor (case-insensitive).
- Currency multi-select.
- Asset Class/Subclass (optional) — using existing taxonomy.
- Status toggles:
  - Missing Price Only (no row in `InstrumentPriceLatest`).
  - Stale Price (older than N days; configurable, default 7).
  - Edited Only (rows with unsaved changes).
- Date range: filter by latest price “as of” before/after date.

## Sorting

- Sort by: Instrument, Currency, Latest Price, As Of, Source, Status (missing/stale first), Edited state.
- Multi-sort (shift-click) or toolbar with priority order.

## Batch Actions

- Apply As Of to selected rows.
- Apply Source to selected rows.
- Set Price for selected rows to constant value.
- Adjust selected by percentage (+/- x%) for split adjustments.
- Save Selected / Save All (commits edits via `upsertPrice`).

## Editing & Validation

- New Price: positive decimal; localized parsing; thousand separators allowed.
- As Of: ISO-8601 date; cannot be in the future (warn).
- Currency mismatch guard: prices must be saved with the instrument’s currency.
- Conflict check: highlight if another user updated that instrument after load (requery before commit and show as-of/source conflict).

## Data Model

- Load rows via single query (pseudo-SQL):
  ```sql
  SELECT i.instrument_id,
         i.instrument_name,
         i.currency,
         ipl.price,
         ipl.as_of,
         ipl.source,
         ac.class_name,
         asc.sub_class_name,
         i.ticker_symbol,
         i.isin,
         i.valor_nr
    FROM Instruments i
    LEFT JOIN InstrumentPriceLatest ipl ON ipl.instrument_id = i.instrument_id
    JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
    JOIN AssetClasses ac ON asc.class_id = ac.class_id
   WHERE i.is_active = 1
  ;
  ```
- Save per row using `DatabaseManager.upsertPrice(instrumentId:price:currency:asOf:source:)`.

## Performance

- Lazy loading (paging or incremental) for very large lists.
- Debounced search; in-memory filtering after initial load, or paged DB filtering if dataset is big.
- Keep a map of edited rows; avoid reloading entire dataset after each save — update in place.

## UX Details

- Toolbar:
  - Search field
  - Filters (Currency, Class, Subclass, Missing, Stale, Edited)
  - Batch actions menu
  - Save Selected / Save All
- Keyboard:
  - Cmd+S: Save Selected / Save All
  - Arrow keys to navigate cells; Enter to commit cell; Esc to revert cell
- Badges:
  - Missing (red), Stale (orange), Fresh (green)

## Logging

- Log price save events with instrument id, source, as_of, and actor.

## Next Steps

1. Implement data fetch in `DatabaseManager+InstrumentPrice` (new method to list instruments with latest price and metadata with filters).
2. Scaffold `PriceMaintenanceView` table with real rows and editing state.
3. Add toolbar filters and batch actions.
4. Wire up saves and conflict checks.
5. Add navigation entry (Sidebar: Prices).
