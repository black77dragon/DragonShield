# Ichimoku Dragon – User Guide

The Ichimoku Dragon module extends DragonShield with a fully local momentum scanner for US equities. This guide walks through the workflow, UI and scheduling controls.

## Daily Workflow

1. **Run or schedule the scan**
   - Open **Overview → Ichimoku Dragon** in the sidebar.
   - Click *Run Daily Scan* to fetch fresh data, recompute indicators and refresh recommendations on demand.
   - A background scheduler (default 22:00 Europe/London) triggers the same pipeline automatically; the next execution time is shown on the dashboard.

2. **Review the dashboard**
   - The *Top Candidates* table lists the ranked momentum opportunities with Tenkan/Kijun values, slopes and distance metrics.
   - A CSV report is exported after each run to `~/Library/Application Support/DragonShield/IchimokuReports`. Use *Open CSV Report* to inspect the file.

3. **Manage positions**
   - When you decide to act on a candidate, confirm it in the *Watchlist* section. The system tracks close + Kijun and flags exits automatically.
   - *Sell Alerts* list every close-below-Kijun trigger. Resolve an alert once handled.

4. **Browse history & logs**
   - The *History* tab displays the execution log (start/end, candidates, alerts). Use the date picker on the dashboard to revisit past recommendation sets.

5. **Tune settings**
   - Adjust scan window, regression length, run schedule and timezone under the *Settings* tab. Changes persist in the encrypted SQLite configuration store.

## Data & Indicators

- **Universe**: Bundled tickers for S&P 500 and Nasdaq 100. Universe bootstrap runs automatically on first launch.
- **Data source**: Yahoo Finance daily OHLC (fallback hooks for Finnhub/CoinGecko via existing provider registry).
- **Indicators**: Tenkan (9), Kijun (26), Senkou A/B (shifted 26), Chikou, regression slopes (default 5 days). Ties break on price–Kijun distance then Tenkan–Kijun spread.
- **Sell logic**: Close < Kijun closes a position and logs an alert. Hooks are ready for future exit refinements.

## Troubleshooting

- If the scheduler is disabled or misconfigured, the dashboard shows *Next scheduled run: —*. Re-enable the toggle and ensure the timezone string is valid (e.g. `Europe/London`).
- Missing ticker data (delistings, IPOs < 52 sessions) are skipped. Errors are logged in the *Logs* tab.
- The CSV report path is printed on the dashboard; delete older files manually if storage is a concern.

For architectural details see `docs/IchimokuDragon/architecture.md`.
