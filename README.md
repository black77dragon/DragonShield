# Dragon Shield – Personal Asset Management 🐉🛡️

**Version 2.24** | August, 17th, 2025

Dragon Shield is a native macOS application for private investors to track, analyze and document all assets entirely offline. Every byte of financial data remains on your Mac, encrypted in a local database—no cloud, no telemetry.

The app follows Apple's best-in-class UX conventions while embracing ZEN-minimalism for clarity and focus.
For detailed interface guidelines, see the [Dragon Shield UI/UX Design Guide](DragonShield/docs/UX_UI_concept/dragon_shield_ui_guide.md).

## ✨ Key Features (End-Goal Vision)

- **Local-First & Private**: Data never leaves your Mac. No sync, no external servers.
- **Encrypted Storage**: Portfolio encrypted at rest with SQLCipher (AES-256).
- **Diverse Asset Tracking**: Stocks, ETFs, Bonds, Real Estate, Crypto, Options, Structured Products, Cash/Bank Accounts.
- **Document Parsing**: Import monthly statements in CSV, XLSX or PDF (German & English) with automatic ISIN/symbol, quantity, price and fee extraction.

### Additional Features
- **Target Allocation & Alerts**: Define goals per class/instrument; automatic gap calculation and alerting
- **Transaction History**: Chronological log with rich filter & sort, CSV export
- **Positions**: Lists position reports directly from the database with account and instrument details
- **Strategy Documentation**: Markdown notes field beside each instrument and at portfolio level
- **Native macOS Experience**: Swift + SwiftUI, system dark/light mode, Touch ID unlock (planned)
- **Minimalist UI**: Single accent color, generous whitespace, keyboard-first workflow (⌘-K palette)
- **Ichimoku Dragon Scanner**: Python tool that ranks S&P 500 and Nasdaq 100 stocks by Ichimoku momentum and emails the top five daily

## 🚧 Current Status & Roadmap

This project follows an Agile, iterative approach.

### Completed
- ✅ **Iteration 0 — Bedrock**
  - Repo & Xcode scaffold
  - Encrypted SQLite schema
  - Swift⇄Python CLI bridge

- ✅ **Iteration 1 — Manual CRUD**
  - Add / edit instruments & transactions

- ✅ **Iteration 2 — Dashboard Tile 1**
  - Allocation vs. target visual

### In Progress
- 🟡 **Iteration 3 — Import v1**
  - CSV/XLSX parser (German)

### Upcoming
- ⏭ Alerts engine
- ⏭ PDF parser
- ⏭ Options valuation
- ⏭ Touch ID key management
- ⏭ Public beta
- ⏭ iOS App (Phase 1): read‑only viewer for iPhone using a SQLite snapshot exported from the Mac app. See docs/ios_app_design.md. Snapshot export is available in Settings → Data Export.

*Legend: 🟡 = active • ⏭ = next*

## 🛠️ Technology Stack

- **Frontend**: Swift / SwiftUI (+ Charts)
- **Backend Logic**: Python 3.11 (parsing, analytics)
- **Database**: Encrypted SQLite (SQLCipher v4)
- **Build Tools**: Xcode 15+, SwiftPM, Python venv
- **Swift⇄Python Bridge**: CLI invocation (Swift spawns Python scripts)

## 📁 Project Structure

```
DragonShield/
├── DragonShieldApp.swift          # Entry point
├── Views/                         # SwiftUI screens
├── Models/ & Services/            # Combine, data access
├── python_scripts/                # Parsers, analytics
├── db/                            # database migrations (dbmate)
├── docs/                          # documentation and ADRs
│   └── ios_app_design.md          # iOS Phase 1 design (read‑only, snapshot import)
├── tests/                         # Unit & UI tests
├── README.md                      # This file
└── LICENSE
```

## 🚀 Getting Started / Setup

1. **Clone the repository**
   ```bash
   git clone <your-repository-url>
   cd DragonShield
   ```

2. **Create Python virtual environment**
   ```bash
   python3 -m venv .venv
   ```

3. **Activate virtual environment**
   ```bash
   source .venv/bin/activate
   ```

4. **Install Python dependencies**
   ```bash
   pip install -r requirements.txt
   ```
   All required packages are listed in `requirements.txt`.

5. **Run database migrations**
   ```bash
   dbmate --migrations-dir DragonShield/db/migrations --url "sqlite:DragonShield/dragonshield.sqlite" up
   ```
6. **Open the Xcode project**
   ```bash
   open DragonShield.xcodeproj
   ```
7. **Build & run**
   - Select DragonShield → My Mac and press ⌘R

> **⚠️ Important**: The current build is developer-only. Replace the default DB key with a Keychain-managed key before storing real data.

## 💾 Database Information

- **Type**: SQLite
- **Production Folder**: `/Users/renekeller/Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield`
  - Primary database: `dragonshield.sqlite`
  - Test database: `dragonshield_test.sqlite`
  - Backup directory: `Dragonshield DB Backup` (full, reference and transaction backups)
  - Apply migrations with `dbmate --migrations-dir DragonShield/db/migrations --url "$DATABASE_URL" up`.
  - Full database backup/restore via `python3 python_scripts/backup_restore.py`
- **Encryption**: SQLCipher (AES-256)
- **Migrations**: `DragonShield/db/migrations`
- **Dev Key**: Temporary; do not use for production data

### Export Snapshot for iOS
Use Settings → **Export to iCloud Drive…** to generate a consistent read‑only `DragonShield_YYYYMMDD_HHMM.sqlite` file. Import the file in the iOS app via the Files app on your iPhone.

## Updating the Database

Run dbmate to apply migrations and copy the database to the container's Application Support folder. The command prints the applied versions and final path:

```bash
dbmate --migrations-dir DragonShield/db/migrations --url "$DATABASE_URL" up
```

### ZKB CSV Import
Drag a `Depotauszug*.csv` file onto the **Import ZKB Statement** zone in the Data Import/Export view or use *Select File* to choose it manually. The parser maps all rows to the PositionReports table.


### GPT Shell
A small CLI to experiment with OpenAI function calls. Requires `OPENAI_API_KEY` in the environment.

```bash
python3 python_scripts/gpt_shell.py list
python3 python_scripts/gpt_shell.py schema echo
python3 python_scripts/gpt_shell.py call echo '{"text": "hello"}'
```
## 💡 Usage

At present the application must be run from Xcode. Future releases will ship a signed & notarized .app bundle.

## 🛠 Troubleshooting

See [DragonShield/docs/troubleshooting.md](DragonShield/docs/troubleshooting.md) for solutions to common issues. This includes the harmless
`default.metallib` warning printed by the Metal framework on some systems.

## 🤝 Contributing

This is a personal passion project, but issues and PRs are welcome. Please keep PRs focused and well-documented.

## 📜 License

-Dragon Shield is released under the MIT License. See LICENSE for full text.


## Version History
- 2.24: Search for Python interpreter in Homebrew locations or env var.
- 2.23: Run parser via /usr/bin/python3 to avoid sandbox xcrun error.
- 2.22: Launch parser via /usr/bin/env and return exit codes.
- 2.21: Add source-path fallback for locating parser module.
- 2.20: Simplify parser invocation using module path and PYTHONPATH.
- 2.19: Expand parser search to PATH and parent directories.
- 2.18: Search Application Support and env var path for parser.
- 2.17: Display checked parser paths in import error messages.
- 2.16: Enhanced parser lookup and logging for easier debugging.
- 2.13: Added logging guidelines reference document.
- 2.12: Deleting an institution now removes it from the list immediately.
- 2.11: Improved Institutions maintenance UI with edit and delete actions.
- 2.10: Institutions screen now supports add, edit and delete with dependency checks.
- 2.9: Added Hashable conformance for InstitutionData.
- 2.8: Fixed compile issue in AccountsView.
- 2.7: Added Institutions table and management view.
- 2.6: Updated default database path to container directory.
- 2.5: Settings view shows database info and added `db_tool.py` utility.
- 2.4: Import script supports multiple files and shows summaries.
- 2.3: Import tool compatible with Python 3.8+.
- 2.2: Removed bundled database; added generation instructions and ignore rule; documented schema version 4.7 and added `db_version` configuration; added requirements file and clarified setup instructions; automated database build and deployment with version logging; added Python tests and CI workflow.
- 2.1: Documented database deployment script.
- 2.0: Initial project documentation.
