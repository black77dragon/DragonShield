# Transaction Concept

This document describes the transactions‑first model for DragonShield and how it drives holdings and performance with low risk and without schema changes.

## Goals

- Use `Transactions` as the single source of truth.
- Derive holdings and performance from SQL views (`Positions`, `InstrumentPerformance`).
- Provide a clear, safe UX to add, edit, and delete transactions.
- Avoid direct writes to snapshot tables (`PositionReports`) other than for historical import/archive use.

## Data Model

- Table: `TransactionTypes` controls behavior via flags:
  - `affects_position`: BUY/SELL/TRANSFER_IN/TRANSFER_OUT adjust quantity.
  - `affects_cash`: DEPOSIT/WITHDRAWAL (and embedded fees/taxes) adjust cash flow.
  - `is_income`: DIVIDEND/INTEREST income classification.

- Table: `Transactions` stores all activity
  - Key fields: `account_id`, `instrument_id` (nullable for pure cash), `transaction_type_id`, `transaction_date`, `quantity`, `price`, `fee`, `tax`, `net_amount`, `transaction_currency`, `exchange_rate_to_chf`, `amount_chf`, `order_reference`.
  - `order_reference` groups multi‑row actions (e.g., paired position/cash legs).

- Views (already present):
  - `InstrumentPerformance`: avg cost, invested, sold, dividends, quantity, first/last dates.
  - `Positions`: live holdings per account/instrument (quantity and cost metrics) as of `Configuration.as_of_date`.

## Pairing Model (Position + Cash)

One logical action often yields two transaction rows:

- BUY example (10 shares @ 2,000 USD/unit = 20,000 USD total):
  - Row A (position leg): BUY 10 in securities account (USD).
  - Row B (cash leg): WITHDRAWAL 20,000 from USD cash account.
  - Both rows share the same `order_reference`.

- SELL example:
  - Row A: SELL 10 in securities account (USD).
  - Row B: DEPOSIT proceeds (net of fees/taxes) into USD cash account.

This keeps quantity and cash correctly tracked without custom balance logic.

## Constraints and Validations

- Instrument and account currency must match. Instrument currency is master.
- For BUY/SELL, the cash account must have the same currency.
- Negative holdings are hard‑blocked: SELL/TRANSFER_OUT cannot reduce quantity below zero as of the transaction date.
- FX to CHF is computed on save using the latest rate on or before `transaction_date` and stored in `exchange_rate_to_chf` + `amount_chf`.

## UX Flow (Phase 1)

1) Pick transaction date
2) Pick type (BUY, SELL; others later)
3) Pick instrument (position‑affecting types only)
4) Pick securities account (filtered by instrument currency)
5) Pick cash account (same currency; required for BUY/SELL)
6) Enter quantity and price; optional fees/taxes
7) Net is computed (BUY negative; SELL positive)
8) Confirm summary (shows both legs) and save atomically

## Realized P&L

- Start with average‑cost method for realized P&L summaries.
- Add FIFO matching later without schema changes (computed in code or view).

## Phased Implementation

- Phase 1: DatabaseManager CRUD for transactions, FX conversion on save, atomic paired inserts, negative‑holding guard; Transaction form; wire into Transaction History list.
- Phase 2: HoldingsView bound to SQL `Positions`; InstrumentPerformance view UI.
- Phase 3: Realized P&L details (avg cost), optional FIFO engine; trade ledger.
- Phase 4: UX refinements; clearly label current `PositionsView` as Snapshots.
- Phase 5: Route future imports into `Transactions` instead of `PositionReports`.

## Open Questions (captured decisions)

- Cost basis: Average‑cost (decided for start).
- Currency: Instrument and account currency must match (decided); cash account must match as well.
- Transfers: Implement later via guided pair (no cash leg) across two accounts.

