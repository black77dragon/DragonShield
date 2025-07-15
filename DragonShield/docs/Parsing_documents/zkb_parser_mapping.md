# ZKB Depot Statement Parser: Data Mapping

This document outlines the mapping logic for parsing the ZKB "Depotauszug" CSV export and importing its data into the Dragon Shield database schema (v4.13).

---

## 1. Statement-Level Data

| Source                              | ZKB CSV Example                          | Dragon Shield Database Target                 | Transformation / Logic / Notes                                                       |
|:------------------------------------|:-----------------------------------------|:-----------------------------------------------|:-------------------------------------------------------------------------------------|
| **File Name**                       | `Depotauszug Mar 26 2025 ZKB.csv`         | `ImportSessions.filename`                     | Use the full file name.                                                               |
| **Extract Statement Date**          | from file name: `Mar 26 2025`            | `PositionReports.report_date`                 | Parse date with format `MMM DD YYYY` → `2025-03-26`.                                  |
| **CSV Header Row**                  | Row 1 with column titles                 | *N/A*                                         | Skip row 1; begin parsing data at row 2.                                              |
| **Default Institution**             | *(implicit)*                             | `Positions.institution_id`                    | Hard-code to ZKB. (Lookup via `Institutions.name = 'ZKB'`.)                             |
| **Account Mapping**                 | *(not in CSV)*                           | `Accounts.account_id`                         | Use existing ZKB custody account. If none, create with `institution_id = ZKB`.         |

---

## 2. Position & Instrument Mapping (for Securities & Funds)

Data begins on **row 2**. All rows where `Anlagekategorie` **≠ "Konten"** represent a position in a security or fund.

| ZKB CSV Column           | Dragon Shield Database Target           | Transformation / Logic / Notes                                                       |
|:-------------------------|:----------------------------------------|:-------------------------------------------------------------------------------------|
| `Anlagekategorie`        | `InstrumentGroups.group_id`             | Map German category to group code. E.g., 
|                          |                                         | - "Aktien und Ähnliches" → STOCK_GROUP
|                          |                                         | - "Obligationen und Ähnliches" → BOND_GROUP                                          |
| `Anz./Nom.` (first)      | `PositionReports.quantity`              | Number of units. Parse as float.                                                     |
| `(Implied)`              | `PositionReports.purchase_price`        | **Not provided** in ZKB export; leave NULL.                                          |
| `Kurs`                   | `PositionReports.current_price`         | Price per unit. Strip separators (e.g. `.` thousands, `,` decimal) and parse float.   |
| `Währung`                | `PositionReports.currency`              | Currency of instrument position.                                                     |
| `Bezeichnung`            | `Instruments.instrument_name`           | Full name including issue details.                                                   |
| **Extract ISIN**         | `Instruments.isin`                      | Regex extract 12-character ISIN (e.g. `/[A-Z]{2}[A-Z0-9]{10}/`).                     |
| **Extract Valor**        | `Instruments.ticker_symbol`             | If a Valor (Swiss security number) appears, capture numeric code.                    |
| `(Implied)`              | `Instruments.instrument_type_id`        | Set via lookup on group or via `AssetClasses` if available.                          |
| `Wert in CHF`            | *(Informational)*                       | Total market value; not stored in `PositionReports` but used for P&L calculations.   |
| `Bucherfolg (B)`         | *(Informational)*                       | Book result in CHF; may be written to `Transactions.notes`.                           |
| `Rendite (1)`            | *(Informational)*                       | Yield (`Rendite`) as percent; store raw string in `Instruments.notes`.               |
| `Anteil in Prozent`      | *(Informational)*                       | Portfolio weight; not imported.                                                      |

**Error Handling:** If no ISIN can be extracted, skip position and log warning.  

---

*End of ZKB Parser Mapping Document*

