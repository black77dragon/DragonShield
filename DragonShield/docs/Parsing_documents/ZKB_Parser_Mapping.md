# ZKB Statement Parser: Data Mapping

This document outlines the mapping logic for parsing the Zürcher Kantonalbank (ZKB) position statement (`.xlsx` format) and importing its data into the Dragon Shield database schema (v4.4).

## 1. Statement-Level Data

| Source | ZKB XLS Data Example | Dragon Shield Database Target | Transformation / Logic / Notes |
| :--- | :--- | :--- | :--- |
| **File Name** | `Position List Mar 26 2025` | `Transactions.transaction_date` | The date ("2025-03-26") is parsed from the filename and used as the "as-of" date for all imported positions. |
| **Line 6 Content** | "Portfolio-Nr. S 398424-05" | `Accounts.account_number` | The number ("S 398424-05") is extracted. This is used to find or create the main **Custody Account** that holds all security positions. |

---

## 2. Position & Instrument Mapping (for Securities/Funds)

These mappings apply to all rows that are **not** cash accounts (i.e., where `Asset-Unterkategorie` is not "Konten").
All positions originate from the institution **ZKB**, so `Institutions.institution_name` is set to `"ZKB"` for each imported instrument. The worksheet header appears on **row 7**, so parsing begins with data on row 8.

| ZKB XLS Column | Excel Column | Dragon Shield Database Target | Transformation / Logic / Notes |
| :--- | :--- | :--- | :--- |
| `Anlagekategorie` & `Asset-Unterkategorie` | `A`, `B` | `Instruments.group_id` | Mapped to an `InstrumentGroups.group_id` via a configuration map (e.g., "Aktien & ähnliche" -> "Equities"). The sub-category helps refine the mapping (e.g., for bond funds vs. bonds). |
| `Beschreibung` | `E` | `Instruments.instrument_name` | Combined with the institution name "ZKB" and `Whrg.` to form the instrument display name (e.g., `ZKB Kontokorrent Wertschriften CHF`). |
| `ISIN` | `W` | `Instruments.isin` | The primary unique identifier used to look up existing instruments or create new ones. |
| `Valor` | `F` | `Instruments.ticker_symbol` | Used as the ticker symbol for the instrument. |
| `Whrg.` (2nd instance, next to `Kurs`) | `H` | `Instruments.currency` | The trading currency of the instrument itself (e.g., "CHF", "USD"). |
| `Branche` | `AN` | `Instruments.sector` | Directly mapped to the instrument's sector. |
| `Anzahl / Nominal` | `D` | `Transactions.quantity` | The quantity of shares or the nominal value for bonds. If the row describes **ZKB Call Account USD** and this cell is blank, the parser records a value of `0`. |
| `Einstandskurs` | `K` | `Transactions.price` | **Cost Basis.** Used as the price for the initial transaction. For bonds priced in percent (e.g., "99.50%"), the value is converted to a decimal (0.995). |
| `Währung(Einstandskurs)` | `J` | `Transactions.transaction_currency` | The currency in which the `Einstandskurs` is denominated. |
| `Fälligkeit` | `G` | `Instruments.notes` | Maturity date for bonds. Stored in the `notes` field as the current schema doesn't have a dedicated `maturity_date`. Format `DD.MM.YY` is parsed. |
| `Kurs`, `Wert in CHF` | `I`, `N` | *(Informational)* | The current market price and value. Not used for the initial cost-basis transaction but are key for P&L calculations and "exits" reconciliation. |

If the parser does not find a matching instrument by `ISIN`, the import workflow presents a dialog showing the parsed fields (name, ticker, ISIN and currency). The user can adjust these values before the instrument is created and the position is stored.

---

## 3. Cash Account Mapping

This special mapping applies only to rows where `Asset-Unterkategorie` is **"Konten"**. Each such row is processed as a distinct cash account.

| ZKB XLS Column | Dragon Shield Database Target | Transformation / Logic / Notes |
| :--- | :--- | :--- |
| `Anlagekategorie` | `InstrumentGroups.group_id` | The corresponding "cash instrument" that holds the balance will be linked to the "Cash & Money Market" group. |
| `Valor` | `Accounts.account_number` | This (e.g., an IBAN) is used as the unique account number for this new cash account record. |
| `Beschreibung` | `Accounts.account_name` | Used as the name for the new cash account (e.g., "Kontokorrent Wertschriften"). |
| `Whrg.` (1st instance) | `Accounts.currency_code` | The currency of this specific cash account. |
| `(Implied)` | `Accounts.account_type_id` | Mapped to the `account_type_id` for your "Cash Account" `AccountType`. |
| `Anzahl / Nominal` | `Transactions.quantity` & `Transactions.net_amount` | This balance creates a single snapshot/deposit transaction to represent the cash holding as of the statement date. The `price` for this transaction is set to `1.0`. |
| `Devisenkurs` | `ExchangeRates.rate_to_chf` | If the cash account currency is not the base currency (CHF), this value is used to create/update an entry in the `ExchangeRates` table for the statement date. |

If the parser cannot find an existing account matching the portfolio number (for securities) or the `Valor` number (for cash rows), a new account is created automatically using the ZKB institution and the appropriate account type (`CUSTODY` for securities, `CASH` for cash accounts).

