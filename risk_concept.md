# Risk Management Concept for DragonShield

## 1. Core Philosophy

To ensure comparability across diverse assets (from Cash to Crypto Options), DragonShield will adopt the **PRIIPs SRI (Summary Risk Indicator)** standard. This uses a **1-7 integer scale**.

In addition to market volatility (SRI), we will track **Liquidity Risk** explicitly, as many of the defined instruments (e.g., `DEF_CASH`, `DIRECT_RE`) have low volatility but high lock-up periods.

## 2. Risk Dimensions

### 2.1 Summary Risk Indicator (SRI)

  * **Scale:** 1 (Lowest) to 7 (Highest).
  * **Definition:** Measures the potential for loss and volatility (PRIIPs-aligned buckets; fallback to realized volatility when mapping is unavailable).
  * **Storage:** `integer` (1-7).

### 2.2 Liquidity Class

  * **Scale:** Ternary.
      * **Liquid (0):** Tradable daily.
      * **Restricted (1):** Weekly/monthly liquidity or gates/lockups.
      * **Illiquid (2):** Hard to sell or locked (e.g., PE, P2P, direct real estate).
  * **Storage:** `smallint` (0–2) with `0` backward-compatible to prior boolean `is_illiquid = false` and `2` to `true`.

## 3. Instrument Type Mapping Rules

The following table defines the **default** risk mapping for the instrument types currently in use. Users can override these defaults per instrument, and the mapping entries themselves can be added/edited/removed via the Risk Management Maintenance GUI.

| Code | Instrument Name | Default SRI | Liquidity | Rationale |
| :--- | :--- | :---: | :---: | :--- |
| **Cash & Equivalents** | | | | |
| `CASH` | Cash | **1** | Liquid | Risk-free base asset. |
| `MM_INST` | Money Market Instruments | **1** | Liquid | Short-term, high safety. |
| `DEF_CASH` | Deferred Cash | **1** | **Illiquid** | Access restricted; payout timing risk. |
| **Bonds & Fixed Income** | | | | |
| `GOV_BOND` | Government Bond | **2** | Liquid | Developed markets; EM => SRI 3. |
| `CORP_BOND` | Corporate Bond | **3** | Liquid | Investment grade assumption. |
| `BOND_ETF` | Bond ETF | **3** | Liquid | Diversified basket. |
| `DLP2P` | Direct Lending (P2P) | **6** | **Illiquid** | Unsecured consumer/SME credit, default and funding risk. |
| **Equities** | | | | |
| `STOCK` | Single Stock | **5** | Liquid | Idiosyncratic risk, earnings/sector exposure. |
| `EQUITY_ETF` | Equity ETF | **4** | Liquid | Diversified market beta. |
| `EQUITY_FUND`| Equity Fund | **4** | Liquid | Diversified, active risk. |
| **Digital Assets** | | | | |
| `CRYPTO` | Cryptocurrency | **7** | Liquid | Extreme volatility and tail risk. |
| `CRYPTO_FUND`| Crypto Fund | **6** | Liquid | Diversified but high-vol asset class. |
| `CRYP_STOCK` | Crypto Stock | **6** | Liquid | High beta to crypto markets. |
| **Real Assets & Real Estate** | | | | |
| `DIRECT_RE` | Own Real Estate | **2** | **Illiquid** | Stable pricing; very slow exit. |
| `MORT_REIT` | Mortgage REIT | **5** | Liquid | Rate/credit spread sensitive. |
| `COMMOD` | Commodities | **5** | Liquid | High volatility (gold/oil). |
| `INFRA` | Infrastructure | **3** | **Illiquid** | Regulated, stable, slow to exit. |
| **Complex / Derivatives** | | | | |
| `STRUCTURED` | Structured Product | **6** | **Illiquid** | Issuer risk; embedded barriers/paths. |
| `OPTION` | Options | **7** | Liquid | Leverage; full loss possible. |
| `FUTURE` | Futures | **7** | Liquid | Leverage; tail exposure. |
| `HEDGE_FUND` | Hedge Fund | **5** | **Restricted** | Strategy-dependent; gates/lockups common. |
| **Pension & Insurance** | | | | |
| `PENSION_2` | Pension Fund (2nd Pillar)| **2** | **Illiquid** | Long-dated, capital-protected frameworks. |
| `LIFIN` | Life Insurance | **2** | **Illiquid** | Long-term contract; low volatility. |

**Unmapped / new codes:** Default to SRI 5 and Liquidity = Restricted; flag for review in the maintenance GUI.

## 4. Implementation Plan

### 4.1 Database Schema Changes

Create a dedicated `instrument_risk_profile` table (1:1 with `instruments`) to keep risk data isolated and auditable. Core columns:
- `instrument_id` PK/FK to `instruments`
- `computed_sri` INTEGER CHECK 1–7
- `computed_liquidity_tier` SMALLINT CHECK (liquidity_tier BETWEEN 0 AND 2)
- `manual_override` BOOLEAN DEFAULT 0
- `override_sri` INTEGER NULL CHECK 1–7
- `override_liquidity_tier` SMALLINT NULL CHECK (override_liquidity_tier BETWEEN 0 AND 2)
- `override_reason` TEXT NULL
- `override_by` TEXT NULL
- `override_expires_at` TIMESTAMPTZ NULL
- `calc_method` TEXT NULL (e.g., `mapping:v1`, `sri:model:v2`)
- `mapping_version` TEXT NULL (e.g., `risk_map_v1`)
- `calc_inputs` JSONB NULL (source facts used in last calc)
- `calculated_at` TIMESTAMPTZ
- `updated_at` TIMESTAMPTZ DEFAULT now()
- optional: `recalc_due_at` TIMESTAMPTZ for scheduling

If future history is needed, add `as_of`/`version` with a partial index for the current row; otherwise, keep one row per instrument with a unique index on `instrument_id`.

### 4.2 Automation Logic

When creating or updating an instrument:
1. Check `manual_override`. If TRUE, use `override_*` and leave `computed_*` untouched.
2. If FALSE and the type is mapped, set `computed_sri` / `computed_liquidity_tier` from the mapping (store `mapping_version`).
3. If FALSE and the type is unmapped, apply defaults (SRI 5, Liquidity Restricted) and flag for review.
4. (Optional PRIIPs-aligned fallback) If return history is available, bucket annualized volatility: ≤5%→1, 5–10→2, 10–15→3, 15–25→4, 25–35→5, 35–50→6, >50→7; take the max of mapping default and vol bucket.
5. Persist `calc_method`, `calc_inputs` (e.g., type code, vol stats), `calculated_at`, and set `recalc_due_at` based on policy.
6. Effective values for UI/reporting come from `override_*` when `manual_override` is TRUE; otherwise from `computed_*`.

### 4.3 UI Representation

  * **SRI Badge:** Display a colored badge (1-2 Green, 3-5 Yellow/Orange, 6-7 Red).
  * **Liquidity Indicator:** Show icons/labels for Liquid, Restricted, Illiquid; highlight Restricted/Illiquid with a warning color.
  * **Override Visibility:** Indicate when a value is manually overridden and provide a drilldown of rationale and inputs.

### 4.4 Risk Management Maintenance GUI

  * Manage the mapping table: add/edit/delete instrument type entries, set default SRI and Liquidity tier, and version mappings.
  * Configure global defaults for unmapped codes and fallback rules.
  * View and approve override requests; capture `override_reason`, `override_by`, `override_expires_at`.
  * Trigger recalculation and review flagged instruments (e.g., missing mapping, stale calculation, data gaps).

### 4.5 Instrument Maintenance GUI Updates

  * Display computed SRI and Liquidity tier with their source (mapping version and calc time).
  * Allow manual override (SRI and Liquidity) with reason, approver, and optional expiry; toggle `manual_override`.
  * Show the latest calculation inputs (type code, volatility bucket, method) for transparency.

### 4.6 Governance and Recalculation

  * Triggers: scheduled daily batch; plus event-based recalcs on rating changes, vol shocks (>X% change), instrument type change, or mapping version updates.
  * Missing data policy: if vol/credit/liquidity inputs are missing, fall back to mapping defaults and mark the profile as “fallback used”.
  * Review cadence: periodic review of overrides approaching expiry and unmapped codes; log all override changes with user and timestamp.

## 5. Portfolio Risk Scoring Methodology (DS-032)

The portfolio risk score blends value-weighted SRI and liquidity so dashboards and the upcoming “Risks” tab can surface a single posture plus drill-downs.

**Computation steps**
1) **Holdings + value**: take the latest Portfolio Valuation snapshot (PositionReports × InstrumentPriceLatest with FX to base currency) and ignore rows excluded because of missing price/FX or zero position.
2) **Instrument risk inputs**: use `InstrumentRiskProfile.effective_sri` and `effective_liquidity_tier`; if no profile exists, fallback to the mapping defaults for the instrument’s sub-class (or global defaults 5 / Restricted).
3) **Liquidity premium**: map liquidity to a penalty added on top of SRI before weighting:
   * Liquid → `+0.0`
   * Restricted → `+0.5`
   * Illiquid → `+1.0`
4) **Per-instrument blended score**: `blended_i = min(7, sri_i + liquidity_premium_i)`.
5) **Weights**: `weight_i = value_i_base / total_value_base`.
6) **Portfolio aggregates**:
   * `weighted_sri = Σ(weight_i * sri_i)`
   * `weighted_liquidity_premium = Σ(weight_i * liquidity_premium_i)`
   * `portfolio_score = min(7, weighted_sri + weighted_liquidity_premium)`
7) **Category bands** (for tiles/reports):  
   * `Low` ≤ 2.5  
   * `Moderate` ≤ 4.0  
   * `Elevated` ≤ 5.5  
   * `High` > 5.5

**Outputs to surface**
- Portfolio score + category and the base currency / as-of dates used.
- Value-weighted SRI average, liquidity premium, and combined score.
- Distribution by SRI bucket (count + value share) and by liquidity tier.
- Instrument-level contributions: value in base, weight %, SRI, liquidity, blended score, and whether a fallback/default was used.
