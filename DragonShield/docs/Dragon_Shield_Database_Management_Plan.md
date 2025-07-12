
# Dragon Shield – Database Management Concept & Implementation Plan

## 📘 Concept Overview

### Purpose
This concept outlines how to manage, separate, and protect different types of data within the Dragon Shield application as it enters production mode.

### 🔄 Data Categories

#### 1. Reference Data
Foundational values that rarely change and are shared across the application, such as currencies, institutions, account types, and asset classes. These should be clearly separated from user-specific data and editable only with care.

#### 2. User Production Data
Personal and financial records users create—accounts, transactions, portfolios, and position reports. These must be backed up regularly and protected from corruption.

#### 3. Test or Demo Data
Sample data used for testing or development. It must be clearly separated from production data to avoid unintended interference.

### 💾 Backups
Users should be able to create and restore database backups through the app interface. This ensures recovery in case of corruption or errors.

### 🔄 Switching Between Data Sets
The app must support switching between production and test databases. This enables safe experimentation and development.

### 🔁 Data Migration
When structural changes occur in the database, a migration process should ensure existing user data is preserved and updated:
- Track the current database version.
- Detect required upgrades before applying changes.
- Provide user feedback and fallback options.

### 📊 Versioning
The system must track the version of the database schema in use. This allows compatibility checks and controlled updates.

### 🛡️ Goals
- Protect user data with regular, easy backups.
- Keep production and test data clearly separated.
- Allow editing of reference data in a controlled way.
- Ensure smooth and safe migrations when the database changes.
- Provide a fully UI-based data management experience.

---

## 🛠️ Implementation Steps (UI-Only)

### Step 1: Database Management View
- Create a dedicated UI section for all database operations.
- Show database path, size, and schema version.
- Add buttons for Backup, Restore, Switch Mode, and Migrate.
- Clearly display current mode (e.g., TEST or PRODUCTION).

### Step 1b: Reference Data Backup & Restore
- Provide separate "Backup Reference" and "Restore Reference" actions.
- Show timestamp of the last reference backup.
 - Only the Configuration, Currencies, ExchangeRates, AssetClasses, AssetSubClasses,
   AccountTypes, Institutions, TransactionTypes, Instruments and Accounts tables are included.
 - When restoring, run `schema.sql` first so these tables exist before applying the dump.

### Step 2: Backup & Restore via UI
- Add "Create Backup" button that saves the current database file.
- Provide a restore picker to load a selected backup.
- Include safety warnings before overwriting data.

### Step 3: Reference Data Management in UI
- Build editor views for currencies, institutions, and account types.
- Prevent editing or deletion of reference data that is in use.
- Clearly separate reference data editing from user data areas.

### Step 4: Test Data Support
- Add a UI switch to load or initialize a separate test database.
- Ensure visual indicators clearly show when in test mode.
- Load demo/test data into this alternate database.

### Step 5: Display and Manage Schema Version
- Read and show `db_version` from the configuration table.
- Disable features or prompt upgrade if version mismatches.

### Step 6: Data Migration via UI
- Add "Check for Migration" button.
- Compare current schema version to latest.
- Apply stepwise migrations through the app with progress display.

### Step 7: Backup Reminder
- Notify users if no recent backup is found.
- Provide a way to schedule periodic backup reminders.

---

This document provides both the high-level concept and a structured, UI-focused implementation plan for full production-ready data management in Dragon Shield.
