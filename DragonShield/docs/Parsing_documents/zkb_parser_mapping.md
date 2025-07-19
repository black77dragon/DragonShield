# ZKB Depot Statement Parser: Data Mapping

This document outlines the mapping logic for parsing the ZKB "Depotauszug" CSV export and importing its data into the Dragon Shield database schema (v4.14).

---

## 1. Statement-Level Data

| Source                              | ZKB CSV Example                          | Dragon Shield Database Target                 | Transformation / Logic / Notes                                                       |
|:------------------------------------|:-----------------------------------------|:-----------------------------------------------|:-------------------------------------------------------------------------------------|
| **File Name**                       | `Depotauszug Mar 26 2025 ZKB.csv`         | `ImportSessions.filename`                     | Use the full file name.                                                               |
| **Extract Statement Date**          | from file name: `Mar 26 2025`            | `PositionReports.report_date`                 | Parse date with format `MMM DD YYYY` → `2025-03-26`.                                  |
| **CSV Header Row**                  | Row 1 with column titles                 | *N/A*                                         | Skip row 1; begin parsing data at row 2.                                              |
| **Default Institution**             | *(implicit)*                             | `Positions.institution_id`                    | Hard-code to ZKB. (Lookup via `Institutions.name = 'Züricher Kantonalbank ZKB'`.)                             |
| **Account Mapping**                 | *(not in CSV)*                           | `Accounts.account_id`                         | Hard-code to ZKB Custody Account. (lookup via `account_number.name` = `1-2600-01180149` in custody account.         |

---

## 2. Position & Instrument Mapping (for Securities & Funds)

Data begins on **row 2**. All rows where `Anlagekategorie` **≠ "Konten"** represent a position in a security or fund.

| ZKB CSV Column               | Dragon Shield Database Target           | Transformation / Logic / Notes                                                                    |
|:-----------------------------|:----------------------------------------|:--------------------------------------------------------------------------------------------------|
| `Anlagekategorie`            | `AssetSubClasses.sub_class_id`          | Mapped to an AssetSubClasses.sub_class_id via a configuration map in DragonShield/docs/AssetClassDefinitionConcept.md defined in Chapter "8. ZKB Mapping"                                                                                |
| `Anz./Nom.` (first,column B) | `PositionReports.quantity`              | Number of units. Parse as float.                                                                  |
| `Einstandskurs` (first)      | `PositionReports.purchase_price`        | Price paid when first bought. Strip separators (e.g. `.` thousands, `,` decimal) and parse float. |
| `Marktkurs`                  | `PositionReports.current_price`         | Current price per unit. Strip separators (e.g. `.` thousands, `,` decimal) and parse float.       |
| `Währung`                    | `PositionReports.currency`              | Currency of instrument position.                                                                  |
| `Bezeichnung`                | `Instruments.instrument_name`           | Full name including issue details. Only used, if this is a new instrument                         |
| `Valor/IBAN/MSCI ESG-Rating` | `Instruments.valor_nr`                  | Contains the Valoren number .                                                                     |

**Error Handling:** The import process looks up instruments by `Valor/IBAN` first, then by `ISIN`, and finally by `Ticker` symbol. If no match is found using these identifiers, an "Add Instrument" window is shown pre-filled with the parsed details. The user can Save, Ignore or Abort the import of that position. Saving creates the instrument before storing the position; Ignore skips the position and Abort cancels the import.

---

*End of ZKB Parser Mapping Document*

