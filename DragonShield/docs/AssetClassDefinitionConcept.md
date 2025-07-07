# DragonShield - Asset Class Definition Concept

| | |
|---|---|
| **Document ID:** | `AssetClassConcept.md` |
| **Version:** | `1.1` |
| **Date:** | `2025-06-30` |
| **Author:** | `DragonShield Maintainers` |
| **Status:** | `Final` |

---

This document outlines the hierarchical asset classification methodology used within the DragonShield application. It details the rationale, core concepts, and database implementation of the `AssetClasses` and `AssetSubClasses` structure.

## Document History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.1 | 2025-06-30 | System | Added brief introductory description at the top. |
| 1.0 | 2025-06-30 | System | Initial creation of the asset class conceptual document. |

---

## 1. Introduction & Purpose

This document outlines the asset classification methodology used within the DragonShield application. As of schema version 4.9, the system has migrated from a flat `InstrumentGroups` structure to a more robust, hierarchical model.

The previous model was insufficient for accurately classifying complex financial instruments, leading to ambiguity. For example, it was unclear whether an ETF composed of equities should be classified as an "Equity" or an "ETF."

The new, two-tier system, consisting of **`AssetClasses`** and **`AssetSubClasses`**, resolves these issues. It provides a scalable and unambiguous framework that aligns with financial industry best practices, enabling more powerful and accurate portfolio analysis and reporting.

## 2. Core Concepts

The classification model is built upon two core tables in the database schema: `AssetClasses` and `AssetSubClasses`.

### 2.1. Asset Class

An **Asset Class** is the highest-level category of an investment. It groups instruments with similar financial characteristics, risk profiles, and market behaviors. These are broad categories that form the foundation of strategic asset allocation.

In the database, these are defined in the `AssetClasses` table.

**Example `AssetClasses` from Seed Data:**
* Liquidity
* Equity
* Fixed Income
* Real Assets
* Alternatives

### 2.2. Asset Sub-Class

An **Asset Sub-Class** is a more granular classification that belongs to a single parent Asset Class. It defines the specific *type* or *structure* of the instrument within its broader category. Every instrument in the application is assigned a Sub-Class, which in turn rolls up to a primary Asset Class.

This relationship is enforced by a foreign key from the `AssetSubClasses` table to the `AssetClasses` table.

### 2.3. Solving the Classification Problem

This hierarchical structure provides a clear solution to previous ambiguities:

* **Problem:** Is an ETF holding stocks an "ETF" or "Equity"?
* **Solution:** It is both. Its primary `AssetClass` is **Equity**, and its more specific `AssetSubClass` is **Equity ETF**.

This allows for reporting at both a high level (total allocation to Equities) and a granular level (breakdown of Single Stocks vs. Equity ETFs).

## 3. Database Schema Implementation

The following tables from `schema.sql` define the asset classification structure.

### `AssetClasses` Table
This table holds the main categories.

```sql
CREATE TABLE AssetClasses (
    class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_code TEXT NOT NULL UNIQUE,
    class_name TEXT NOT NULL,
    class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
````

### `AssetSubClasses` Table

This table holds the specific instrument types and links back to a parent `AssetClass`.

```sql
CREATE TABLE AssetSubClasses (
    sub_class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id INTEGER NOT NULL,
    sub_class_code TEXT NOT NULL UNIQUE,
    sub_class_name TEXT NOT NULL,
    sub_class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES AssetClasses(class_id)
);
```

### `Instruments` Table (Modified)

The `Instruments` table now contains a foreign key `sub_class_id` to link each instrument to its specific classification.

```sql
CREATE TABLE Instruments (
    instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
    isin TEXT UNIQUE,
    ticker_symbol TEXT,
    instrument_name TEXT NOT NULL,
    sub_class_id INTEGER NOT NULL,
    currency TEXT NOT NULL,
    -- ... other columns
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id),
    FOREIGN KEY (currency) REFERENCES Currencies(currency_code)
);
```

## 4\.Asset Classes and Sub-Classes incl. ZKB Mapping

| Asset Class (Parent) | Asset Sub-Class (Child) | Notes | ZKB Parsing |
| --- | --- | --- | --- |
| **Liquidity** | Cash | Physical and bank account balances. |  |
|  | Money Market Instruments | Short-term, highly liquid debt. | “Geldmarktfonds / CHF” |
| **Equity** | Single Stock | Direct ownership in a company. | “Aktien” + region; region could be “Schweiz”, “Europa”, “Taiwan”, “USA” |
|  | Equity ETF | ETFs that primarily hold stocks. |  |
|  | Equity Fund | Mutual funds that primarily hold stocks. | “Aktienfonds” + region; region could be “Schweiz”, “Europa”, “Taiwan”, “USA” |
|  | Equity REIT | REITs focused on owning/operating real estate. |  |
| **Fixed Income** | Government Bond | Debt issued by national governments. | “Obligationen”+ currency; currency could be “CHF”, “USD”, “GBP” |
|  | Corporate Bond | Debt issued by corporations. | “Obligationen“+ currency |
|  | Bond ETF | ETFs that primarily hold bonds. |  |
|  | Bond Fund | Mutual funds that primarily hold bonds. | “Obligationenfonds” + currency |
| **Real Assets** | Direct Real Estate | Physical property ownership. |  |
|  | Mortgage REIT | REITs focused on real estate financing. |  |
|  | Commodities | Raw materials or primary agricultural products. |  |
|  | Infrastructure | Investments in public works like roads, bridges. |  |
| **Alternatives** | Hedge Fund | Actively managed funds with diverse strategies. | “Hedge-Funds”+ region; region could be “Cayman”, “Europa”, “Taiwan”, “USA” |
|  | Private Equity / Debt | Investments in non-publicly traded companies. |  |
|  | Structured Product | Pre-packaged investments (e.g., certificates). |  |
|  | Cryptocurrency | Digital or virtual tokens. |  |
| **Derivatives** | Options | Contracts giving the right to buy/sell an asset. | Standard-Optionen |
|  | Futures | Contracts to buy/sell an asset at a future date. |  |
| **Other** | Other | Catch-all for unclassified instruments. |  |

## 5\. Examples in Practice

The following table demonstrates how various instruments from the seed data (`schema.txt`) are classified using this system.

| Instrument Name | Asset Sub-Class | Asset Class | Explanation |
|---|---|---|---|
| **Nestlé SA** | `Single Stock` | `Equity` | A direct holding in a publicly traded company. |
| **iShares Core MSCI World UCITS ETF** | `Equity ETF` | `Equity` | An Exchange-Traded Fund that primarily holds a basket of global stocks. |
| **Swiss Confederation 0.5% 2031** | `Government Bond` | `Fixed Income` | A debt instrument issued by the Swiss government. |
| **Bitcoin** | `Cryptocurrency` | `Alternatives` | A digital asset classified under the "Alternatives" class. |
| **Swiss Franc Cash** | `Cash` | `Liquidity` | Represents a holding in a fiat currency, categorized under Liquidity. |

## 5\. Benefits of this Approach

  * **Clarity & Unambiguity:** Every instrument has a clear, two-level classification, eliminating guesswork.
  * **Flexible Reporting:** The portfolio can be analyzed at a high level (e.g., `Equity` vs. `Fixed Income` allocation) or a granular level (e.g., `Single Stock` vs. `Equity ETF` exposure within the `Equity` class).
  * **Scalability:** New and exotic instrument types can be easily added as new `AssetSubClasses` without disrupting the high-level `AssetClass` structure.
  * **Industry Alignment:** This hierarchical model is a standard practice in the financial industry for portfolio management and risk analysis.

<!-- end list -->

```
```
