# Risk Management Concept for DragonShield

## 1. Core Philosophy

To ensure comparability across diverse assets (from Cash to Crypto Options), DragonShield will adopt the **PRIIPs SRI (Summary Risk Indicator)** standard. This uses a **1-7 integer scale**.

In addition to market volatility (SRI), we will track **Liquidity Risk** explicitly, as many of the defined instruments (e.g., `DEF_CASH`, `DIRECT_RE`) have low volatility but high lock-up periods.

## 2. Risk Dimensions

### 2.1 Summary Risk Indicator (SRI)

  * **Scale:** 1 (Lowest) to 7 (Highest).
  * **Definition:** Measures the potential for loss and volatility.
  * **Storage:** `integer` (1-7).

### 2.2 Liquidity Class

  * **Scale:** Binary or Ternary.
      * **Liquid:** Tradable daily (e.g., Stocks, ETFs).
      * **Illiquid:** Hard to sell or locked (e.g., Private Equity, Direct Real Estate, P2P).
  * **Storage:** `boolean` (`is_illiquid`).

## 3. Instrument Type Mapping Rules

The following table defines the **default** risk mapping for the instrument types currently in use. Users should be able to override these defaults on a per-instrument basis.

| Code | Instrument Name | Default SRI | Liquidity | Rationale |
| :--- | :--- | :---: | :---: | :--- |
| **Cash & Equivalents** | | | | |
| `CASH` | Cash | **1** | Liquid | [cite_start]Risk-free base asset[cite: 4]. |
| `MM_INST` | Money Market Instruments | **1** | Liquid | [cite_start]Short-term, high safety[cite: 8]. |
| `DEF_CASH` | Deferred Cash | **1** | **Illiquid** | [cite_start]Solvency risk is low, but access is restricted[cite: 6]. |
| **Bonds & Fixed Income** | | | | |
| `GOV_BOND` | Government Bond | **2** | Liquid | Assumes developed markets. [cite_start]Map to **3** if Emerging[cite: 24]. |
| `CORP_BOND` | Corporate Bond | **3** | Liquid | [cite_start]Default credit risk assumption (Investment Grade)[cite: 22]. |
| `BOND_ETF` | Bond ETF | **3** | Liquid | [cite_start]Diversified basket[cite: 18]. |
| `DLP2P` | Direct Lending (P2P) | **6** | **Illiquid** | [cite_start]Unsecured consumer/SME debt; high default risk[cite: 26]. |
| **Equities** | | | | |
| `STOCK` | Single Stock | **5** | Liquid | [cite_start]High idiosyncratic risk[cite: 58]. |
| `EQUITY_ETF` | Equity ETF | **4** | Liquid | [cite_start]Diversified market risk[cite: 52]. |
| `EQUITY_FUND`| Equity Fund | **4** | Liquid | [cite_start]Actively managed diversified basket[cite: 54]. |
| **Digital Assets** | | | | |
| `CRYPTO` | Cryptocurrency | **7** | Liquid | [cite_start]Extreme volatility[cite: 16]. |
| `CRYPTO_FUND`| Crypto Fund | **6** | Liquid | [cite_start]Diversified but highly volatile asset class[cite: 10]. |
| `CRYP_STOCK` | Crypto Stock | **6** | Liquid | [cite_start]High beta correlation to crypto markets[cite: 14]. |
| **Real Assets & Real Estate** | | | | |
| `DIRECT_RE` | Own Real Estate | **2** | **Illiquid** | [cite_start]Price stable, but extremely hard to liquidate[cite: 50]. |
| `MORT_REIT` | Mortgage REIT | **5** | Liquid | [cite_start]Sensitive to interest rates and credit spreads[cite: 48]. |
| `COMMOD` | Commodities | **5** | Liquid | [cite_start]High volatility (Gold/Oil)[cite: 44]. |
| `INFRA` | Infrastructure | **3** | **Illiquid** | [cite_start]Regulated returns, often stable but slow[cite: 46]. |
| **Complex / Derivatives** | | | | |
| `STRUCTURED` | Structured Product | **6** | **Illiquid** | [cite_start]Issuer risk + often barrier options involved[cite: 32]. |
| `OPTION` | Options | **7** | Liquid | [cite_start]Leverage implies potential for 100% loss[cite: 40]. |
| `FUTURE` | Futures | **7** | Liquid | [cite_start]Unlimited loss potential (theoretically)[cite: 38]. |
| `HEDGE_FUND` | Hedge Fund | **5** | **Illiquid** | [cite_start]Strategies vary, but often gated liquidity[cite: 28]. |
| **Pension & Insurance** | | | | |
| `PENSION_2` | Pension Fund (2nd Pillar)| **2** | **Illiquid** | [cite_start]Capital protection usually mandated[cite: 35]. |
| `LIFIN` | Life Insurance | **2** | **Illiquid** | [cite_start]Long-term contract, low volatility[cite: 33]. |

## 4. Implementation Plan

### 4.1 Database Schema Changes

Create a dedicated `instrument_risk_profile` table (1:1 with `instruments`) to keep risk data isolated and auditable. Core columns:
- `instrument_id` PK/FK to `instruments`
- `computed_sri` INTEGER CHECK 1–7
- `computed_is_illiquid` BOOLEAN
- `manual_override` BOOLEAN DEFAULT 0
- `override_sri` INTEGER NULL CHECK 1–7
- `override_is_illiquid` BOOLEAN NULL
- `calc_method` TEXT NULL (e.g., `mapping:v1`, `sri:model:v2`)
- `calc_inputs` JSONB NULL (source facts used in last calc)
- `calculated_at` TIMESTAMPTZ
- `updated_at` TIMESTAMPTZ DEFAULT now()

If future history is needed, add `as_of`/`version` with a partial index for the current row; otherwise, keep one row per instrument with a unique index on `instrument_id`.

### 4.2 Automation Logic

When creating or updating an instrument:
1. Check `manual_override`. If TRUE, use `override_sri` / `override_is_illiquid` and leave `computed_*` untouched.
2. If FALSE, look up `instrument_type_code` in the mapping table above to set `computed_sri` and `computed_is_illiquid`.
3. Persist `calc_method`, `calc_inputs` (e.g., type code and mapping version), and `calculated_at`.
4. The effective values for UI/reporting come from `override_*` when `manual_override` is TRUE; otherwise from `computed_*`.

### 4.3 UI Representation

  * **SRI Badge:** Display a colored badge (1-2 Green, 3-5 Yellow/Orange, 6-7 Red).
  * **Liquidity Warning:** Show a lock icon for any asset flagged as `is_illiquid`.
