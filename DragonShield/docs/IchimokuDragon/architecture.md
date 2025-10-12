# Ichimoku Dragon Architecture Overview

## Goals
- Scan S&P 500 and Nasdaq 100 equities daily using Ichimoku Kinko Hyo
- Rank bullish momentum candidates and surface the top 5
- Track open positions and generate sell alerts when price falls below Kijun Sen
- Provide an interactive macOS UI (SwiftUI) without external services or email delivery
- Persist all state in encrypted SQLite (SQLCipher) alongside DragonShield data

## High-Level Components

### 1. Universe Management
- `IchimokuTickerRepository` (SQLite): stores ticker metadata, index source, activation flags.
- `UniverseBootstrapper`: seeds the initial S&P 500 & Nasdaq 100 tickers from bundled JSON resources on first launch.
- `UniverseSyncService`: optional manual refresh by importing updated lists (CSV/JSON).

### 2. Historical Data Ingestion
- `IchimokuHistoricalPriceRepository`: reads/writes `ichimoku_price_history` table (250+ daily bars per ticker).
- `IchimokuDataFetcher`: orchestrates downloads via existing providers (Yahoo Finance primary, Finnhub fallback). Supports chunked downloads to respect throttling and stores results in SQLite.
- Scheduler integrates with `SystemJobRuns` for progress logging.

### 3. Indicator Computation
- `IchimokuIndicatorCalculator`: computes Tenkan, Kijun, Senkou A/B, Chikou, slopes (regression-based by default, fallback to simple differences when history is short).
- `IchimokuIndicatorRepository`: persists indicator values and derived metrics.
- Calculations operate incrementally per ticker/date to avoid recomputing entire history.

### 4. Signal & Ranking
- `IchimokuSignalEngine`: filters bullish structure and composes a momentum score = weighted Tenkan/Kijun slope + tie-breakers (price–Kijun distance, Tenkan–Kijun spread, relative volume placeholder).
- `IchimokuDailyCandidateRepository`: stores ranked results per trading day; top five highlighted on dashboard.

### 5. Position Tracking & Alerts
- `IchimokuPositionService`: manages lifecycle of recommended positions, requiring manual confirmation for entries; tracks status and last evaluation.
- `IchimokuSellAlertRepository`: records exit triggers (close < Kijun) and audit trail of actions.

### 6. Reporting & UI
- `IchimokuReportService`: builds CSV summaries stored under Application Support; surfaced in the History view with quick export.
- `IchimokuDashboardView`, `IchimokuWatchlistView`, `IchimokuHistoryView`, `IchimokuSettingsView`, `IchimokuLogsView`: SwiftUI scenes wired through a parent `IchimokuDragonView` and a dedicated `IchimokuDragonViewModel`.
- Uses Combine publishers from repositories/services to drive UI updates.

### 7. Scheduling & Configuration
- `IchimokuScheduler`: configurable trigger (default 22:00 Europe/London). Persists schedule + enable/disable flag in `Configuration` table (`ichimoku.schedule.enabled`, `ichimoku.schedule.timezone`, `ichimoku.schedule.time`).
- Manual run commands remain available from the dashboard.
- Configuration settings surface in Settings view and map to `DatabaseManager.upsertConfiguration`.

## SQLite Schema Additions

| Table | Purpose |
| ----- | ------- |
| `ichimoku_tickers` | Universe metadata: symbol, name, index source, whether active/manual watch |
| `ichimoku_price_history` | Daily OHLCV data; composite PK (ticker_id, price_date) |
| `ichimoku_indicators` | Daily Ichimoku components + slopes, derived metrics |
| `ichimoku_daily_candidates` | Ranked momentum candidates per trading day |
| `ichimoku_positions` | Active/closed positions seeded by user confirmation |
| `ichimoku_sell_alerts` | Exit alerts when price < Kijun |
| `ichimoku_run_log` | Execution metadata for scans (start/end, outcome, summary) |

Indexes are added to support latest-by-date queries and cleanup.

## Data Flow Summary
1. Scheduler/Manual run triggers `IchimokuPipelineService`.
2. Fetcher downloads missing OHLC history and stores it.
3. Calculator computes indicators for new dates.
4. Signal engine scores candidates and updates `ichimoku_daily_candidates`.
5. Position service updates open positions, generates alerts, records run log entry.
6. UI refreshes via Combine publishers; History view displays new run + CSV export option.

## External Dependencies
- Reuses existing DragonShield price providers (Yahoo, Finnhub) for data.
- No new third-party frameworks required.

## Open Items / Future Iterations
- Automatic universe synchronization using provider APIs.
- Additional ranking tie-breakers (e.g. relative volume, ATR-based volatility filter).
- Refined exit logic (Tenkan/Kijun crossovers, trailing stops).
- Alert notifications once global alerting framework is ready.
