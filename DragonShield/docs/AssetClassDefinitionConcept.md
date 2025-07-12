# DragonShield - Asset Class Definition Concept

|                             |                                                 |
|-----------------------------|-------------------------------------------------|
| **Document ID:**            | `AssetClassConcept.md`                         |
| **Version:**                | `2.1`                                           |
| **Date:**                   | `2025-07-08`                                    |
| **Author:**                 | `DragonShield Maintainers`                      |
| **Status:**                 | `Draft`                                         |

---

## Document History

| Version | Date       | Author                   | Changes                                                                                     |
|---------|------------|--------------------------|---------------------------------------------------------------------------------------------|
| 1.0     | 2025-06-30 | System                   | Initial creation of the asset class conceptual document.                                     |
| 1.1     | 2025-06-30 | System                   | Added brief introductory description at the top.                                            |
| 2.0     | 2025-07-08 | DragonShield Maintainers | Merged hierarchical and unified model; added crypto subclass; consolidated benefits.        |
| 2.1     | 2025-07-08 | DragonShield Maintainers | Added Credit-Suisse Mapping section.                                                                  |

---

## 1. Introduction & Purpose

This document defines the hierarchical asset classification methodology adopted by the DragonShield application. It replaces the legacy flat `InstrumentGroups` structure with a robust two-level taxonomy—`AssetClass` and `AssetSubClass`—to ensure clarity, consistency, and extensibility across all asset types, including cash, securities, derivatives, commodities, and alternative investments.

---

## 2. AssetClass Table

| AssetClass Code | Description                             |
|-----------------|-----------------------------------------|
| LIQ             | Liquid assets (cash, money market)      |
| EQT             | Equity securities                       |
| FIX             | Fixed income instruments (bonds, notes) |
| COM             | Commodities                             |
| DER             | Derivative contracts                    |
| ALT             | Alternative investments (real estate, hedge funds, crypto) |

---

## 3. AssetSubClass Table

| AssetClass | SubClass Code | Description                                             |
|------------|---------------|---------------------------------------------------------|
| LIQ        | CASH          | Cash instruments (e.g. USD_CASH, CHF_CASH)             |
| LIQ        | MMKT          | Money market funds                                      |
| EQT        | AGM           | American equity                                         |
| EQT        | EGM           | European equity                                         |
| FIX        | GOV           | Government bonds                                        |
| FIX        | CORP          | Corporate bonds                                         |
| COM        | ENR           | Energy commodities                                      |
| COM        | MET           | Metal commodities                                       |
| DER        | OPT           | Options                                                 |
| DER        | FUT           | Futures                                                 |
| ALT        | RE            | Real estate investments                                 |
| ALT        | HF            | Hedge funds                                             |
| ALT        | CRY           | Cryptocurrencies (e.g. Bitcoin, Ethereum)               |

---

## 4. Instruments

All assets are represented as entries in the `INSTRUMENT` table:

- **Cash instruments:** `USD_CASH`, `CHF_CASH`, etc., under `SubClass` = `CASH`, `AssetClass` = `LIQ`.
- **Securities:** equities (`AAPL_US`, `NESN_SW`), fixed income (`US9128285M81`), etc.
- **Commodities & Derivatives:** futures, options, commodity codes.
- **Alt & Crypto:** real estate funds, hedge funds, cryptocurrencies (`BTC`, `ETH`).

Each instrument record includes:

- `instrument_id`
- `name` / `ticker` / `ISIN`
- `assetclass_id` (FK to AssetClass)
- `assetsubclass_id` (FK to AssetSubClass)

---

## 5. Unified Accounts, Transactions & Positions Model

- **Accounts table:** single table for all account types (`BANK`, `CUSTODY`, `CASH`, etc.), distinguished by `account_type_id`.
- **Cash as an instrument:** cash accounts are simply accounts whose primary positions are cash instruments.
- **Transactions table:** every movement—buys, sells, deposits, withdrawals, transfers—references an `instrument_id`, `account_id`, and `quantity`/`amount`.
- **Positions view:** aggregates by `account_id` + `instrument_id`, yielding all asset positions side by side.

**Benefits:**

| Category            | Details                                                                 |
|---------------------|-------------------------------------------------------------------------|
| **Clarity**         | Two-level taxonomy eliminates ambiguity in asset classification.         |
| **Uniformity**      | Single schema for all asset types—no special cases for cash vs securities. |
| **Simplicity**      | Parsers and reports handle any asset identically.                       |
| **Extensibility**   | New instruments (e.g., FX forwards, crypto) plug in without model changes.|
| **Reporting**       | Flexible reporting at class, subclass, or instrument level.             |
| **Industry Alignment** | Aligns with best practices in portfolio management and risk analysis. |

---

## 6. Examples

| Instrument Name    | SubClass Code | AssetClass Code | Description                                                    |
|--------------------|---------------|-----------------|----------------------------------------------------------------|
| Bitcoin (BTC)      | CRY           | ALT             | A digital currency classified under cryptocurrencies.          |
| Swiss Franc Cash   | CASH          | LIQ             | Fiat currency cash instrument in Swiss Franc.                 |
| Apple Inc Shares   | AGM           | EQT             | American equity representing AAPL common stock.               |
| US Treasury T-Bill | GOV           | FIX             | Short-term US government debt instrument.                     |

---

## 7. Credit-Suisse Mapping

| Credit-Suisse Group               | AssetClass Code | AssetSubClass Code | Notes                         |
|-------------------------|-----------------|--------------------|-------------------------------|
| Cash                    | LIQ             | CASH               | Bank deposit cash balances.   |
| Money Market Funds      | LIQ             | MMKT               | Money market instruments.     |
| Equities (US)           | EQT             | AGM                | American equities.            |
| Equities (EU)           | EQT             | EGM                | European equities.            |
| Government Bonds        | FIX             | GOV                | Sovereign debt.               |
| Corporate Bonds         | FIX             | CORP               | Corporate debt.               |
| Energy Commodities      | COM             | ENR                | Oil, gas, etc.                |
| Metal Commodities       | COM             | MET                | Gold, silver, etc.            |
| Options                 | DER             | OPT                | Exchange-traded options.      |
| Futures                 | DER             | FUT                | Exchange-traded futures.      |
| Real Estate Investments | ALT             | RE                 | RE funds, REITs.              |
| Hedge Funds             | ALT             | HF                 | Various strategies.           |
| Cryptocurrencies        | ALT             | CRY                | BTC, ETH, etc.                |

---

Below is a concrete illustration of how a Credit-Suisse setup would look in your unified model. We show three tables—​Accounts, Instruments, and Positions—​with sample data for:
	•	Two cash accounts at Credit-Suisse (CHF and USD)
	•	One Credit-Suisse custody account
	•	Cash instruments & two equities

# Credit-Suisse Example in DragonShield Model

## 1. Accounts

| account_id | account_name             | account_type | bank |
|-----------:|--------------------------|--------------|------|
| 101        | Credit-Suisse CHF Cash Account     | CASH         | Credit-Suisse  |
| 102        | Credit-Suisse USD Cash Account     | CASH         | Credit-Suisse  |
| 201        | Credit-Suisse Custody Account      | CUSTODY      | Credit-Suisse  |

## 2. Instruments

| instrument_id | ticker   | assetclass | assetsubclass |
|--------------:|----------|------------|---------------|
| 1             | CHF_CASH | LIQ        | CASH          |
| 2             | USD_CASH | LIQ        | CASH          |
| 10            | AAPL_US  | EQT        | AGM           |
| 20            | NESN_SW  | EQT        | EGM           |

## 3. Positions

| account_id | instrument_id | quantity | comment                                |
|-----------:|--------------:|---------:|----------------------------------------|
| 101        | 1             | 50 000   | CHF cash in CHF Cash Account           |
| 102        | 2             | 30 000   | USD cash in USD Cash Account           |
| 201        | 10            | 100      | Apple shares in Custody Account        |
| 201        | 20            | 50       | Nestlé shares in Custody Account       |
| 201        | 1             | 10 000   | CHF cash _within_ Custody Account      |
| 201        | 2             | 5 000    | USD cash _within_ Custody Account      |

---

### Interpretation

- **Cash Accounts (101, 102)**  
  - Each is its own “CASH” account.  
  - Only holds its corresponding cash instrument.

- **Custody Account (201)**  
  - Holds both securities (AAPL_US, NESN_SW) and cash instruments (CHF_CASH, USD_CASH).  

- **Unified Treatment**  
  - Deposits/withdrawals and buy/sell operations all reference an `instrument_id`.  
  - Single Positions view aggregates cash and securities identically.  

*End of Asset Class Definition Concept (v2.1 with Credit-Suisse mapping)*

