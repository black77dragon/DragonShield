 # Automatic Instrument Price Update — Design

 ## Goals
 - Enable manual, bulk price updates for selected instruments via pluggable data providers.
 - Allow per‑instrument toggle to opt into auto update and select a provider + provider‑specific instrument identifier (kept separate from internal IDs like ISIN/VALOR).
 - Normalize and persist prices to `InstrumentPrice` (via existing `upsertPrice`) with proper currency/as_of/source metadata and audit logging.

 ## User Flows
 - Select instruments (multi‑select) in Prices Maintenance view.
 - For each instrument, set:
   - Update enabled: on/off
   - Provider: e.g., `yahoo`, `alphavantage`, `coingecko`, `custom`
   - Provider Instrument ID (external id): provider‑specific symbol/id (kept separate from ticker/isin/valor).
 - Click "Fetch Latest Prices" to update selected instruments.
 - Review results (success, unchanged, failed) with messages; optionally commit (already stored via `upsertPrice`) and clear edits.

 ## Database Changes (new table + optional log)
 - `InstrumentPriceSource` (per instrument, can support multiple providers with priority):
   - `id INTEGER PRIMARY KEY`
   - `instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE CASCADE`
   - `provider_code TEXT NOT NULL` (enum string, e.g., `yahoo`, `alphavantage`, `coingecko`)
   - `external_id TEXT NOT NULL` (provider’s symbol/id)
   - `enabled INTEGER NOT NULL DEFAULT 1` (0/1)
   - `priority INTEGER NOT NULL DEFAULT 1` (lower value means higher priority)
   - `last_status TEXT NULL` (e.g., `ok`, `not_found`, `rate_limited`)
   - `last_checked_at TEXT NULL` (ISO8601)
   - Unique index on `(instrument_id, provider_code)`

 - `InstrumentPriceFetchLog` (optional, for audit):
   - `id INTEGER PRIMARY KEY`
   - `instrument_id INTEGER`
   - `provider_code TEXT`
   - `external_id TEXT`
   - `status TEXT` (`ok`, `skipped`, `error`)
   - `message TEXT`
   - `created_at TEXT NOT NULL DEFAULT current_timestamp`

 ## Provider Abstraction
 - Define a protocol to fetch a latest quote given `(provider_code, external_id)`:
   - `func fetchLatest(externalId: String, currency: String?) async throws -> Quote`
   - Quote: `{ price: Double, currency: String, asOf: Date, source: String }`
 - Provider registry maps `provider_code` → concrete provider.
 - Providers handle request signing, rate limits, backoff, and normalization.

 ## Normalization & Validation
 - Ensure returned currency matches instrument’s currency; if not, either reject or convert using FX service (configurable; default: reject).
 - Clamp/validate price (non‑negative, reasonable bounds) and truncate precision per currency.
 - `as_of` policy: prefer provider’s timestamp; fallback to fetch time.

 ## UX in Prices Maintenance View
 - Add columns/controls:
   - `Auto` toggle (enabled)
   - `Provider` picker
   - `External ID` text field
 - Toolbar actions:
   - `Fetch Latest` for selected rows (shows progress + results);
   - Optional: `Validate Only` (dry run), `Retry Failed`, `Clear Results`.
 - Show per‑row status chip (OK/Failed/Unchanged) after a run.

 ## Credentials & Security
 - Store provider API keys in Keychain; never in repo.
 - Add a small settings panel for API keys with secure text fields.

 ## Error Handling & Logging
 - Structured logs via `LoggingService` and optional `InstrumentPriceFetchLog` row per attempt.
 - Distinguish provider/network errors, not found, rate limit, invalid symbol.
 - Backoff on 429; aggregate summary at end of batch.

 ## Performance & Limits
 - Batch with concurrency limits (e.g., 3–5 concurrent fetches) to respect provider policies.
 - De‑duplicate identical provider calls (same external id/currency) within a batch.

 ## Testing
 - Provider protocol easily mockable; add test provider returning fixed quotes.
 - Add a "Manual JSON" provider to ingest quotes from a pasted JSON snippet for QA.

 ## Rollout Plan
 1) Add DB tables + UI controls for provider/external id + toggle.
 2) Implement provider protocol, registry, and one concrete provider (e.g., mock or CoinGecko for crypto).
 3) Add batch fetch UI with progress + results, logging.
 4) Validate currencies and as_of behavior; then consider FX conversion if desired.

