### **Dragon Shield – Database Management Concept & Implementation Plan (Version 2.1)**

#### 📘 **Concept Overview**

**Purpose**

This concept outlines how to manage, separate, and protect different types of data within the Dragon Shield application as it enters production mode.

-----

**🔄 Data Categories**

1.  **Reference Data**: Foundational values that rarely change (currencies, institutions, etc.).
2.  **User Production Data**: Personal and financial records created by the user.
3.  **Test or Demo Data**: Sample data for development, kept separate from production data.

-----

**💾 Backups**

Users should be able to create and restore database backups through the app interface to ensure recovery from errors.

-----

**🔁 Data Migration**

When structural changes occur, a migration process using sequential SQL scripts should ensure existing user data is preserved and updated.

-----

**📊 Versioning**

The system must track the database schema version to allow for compatibility checks and controlled updates.

-----

**🛡️ Goals**

  * Protect user data with regular, easy backups.
  * Keep production and test data clearly separated.
  * Allow controlled editing of reference data.
  * Ensure smooth and safe migrations when the database changes.
  * Provide a fully UI-based data management experience.

-----

### **Database Schema Management**

The project has transitioned from a single `schema.sql` file to an incremental migration script system. This is the authoritative method for managing all database schema changes.

**How to Build or Reconstruct the Database**

To create a new database with the most up-to-date schema, you **must** execute the following SQL scripts in their numbered, sequential order.

**Required Scripts in Order:**

1.  `001_baseline_schema.sql`
2.  `002_add_validation_status.sql`
3.  `003_fix_allocation_triggers.sql`
4.  `004_add_validation_findings.sql`
5.  `005_apply_zero_target_skip_rule.sql`
6.  `006_sync_validation_status.sql`
7.  `007_sync_views_and_triggers.sql`

**Example Command-Line Execution**

This example shows how to create a new database file named `new_database.sqlite` and apply all migrations.

```bash
# 1. Create an empty database file
sqlite3 new_database.sqlite ""

# 2. Apply all migration scripts sequentially
sqlite3 new_database.sqlite < 001_baseline_schema.sql
sqlite3 new_database.sqlite < 002_add_validation_status.sql
# ...continue for all scripts up to 007
sqlite3 new_database.sqlite < 007_sync_views_and_triggers.sql
```

**Important Note:** The file `schema.sql` is now **deprecated** and should no longer be used. The authoritative source for the database structure is the sequence of numbered migration scripts.

-----

### 🛠️ **Implementation Steps (UI-Only)**

**Step 1: Database Management View**

  * Create a dedicated UI section for all database operations.
  * Show database path, size, and schema version.
  * Add buttons for Backup, Restore, Switch Mode, and Migrate.
  * Clearly display the current mode (e.g., TEST or PRODUCTION).

**Step 1b: Reference Data Backup & Restore**

  * Provide separate "Backup Reference" and "Restore Reference" actions.
  * The backup should include tables like `Configuration`, `Currencies`, `AssetClasses`, `Institutions`, etc.
  * When restoring, the application must ensure the database schema is up-to-date by applying all necessary migration scripts **before** importing the reference data dump.

**Step 2: Backup & Restore via UI**

  * Add a "Create Backup" button that saves the entire current database file.
  * Provide a restore picker to load a selected backup, with clear warnings before overwriting data.

**Step 3: Reference Data Management in UI**

  * Build editor views for currencies, institutions, and other reference tables.
  * Prevent editing or deletion of reference data that is currently in use.

**Step 4: Test Data Support**

  * Add a UI switch to load or initialize a separate test database.
  * The test database should be built by running the full migration script sequence.
  * Ensure visual indicators clearly show when in test mode.

**Step 5: Display and Manage Schema Version**

  * Read and show the `db_version` from the configuration table.
  * Disable features or prompt for an upgrade if the version mismatches the application's required version.

**Step 6: Data Migration via UI**

  * Add a "Check for Updates" or "Migrate" button.
  * The app will compare the current `db_version` to the latest available migration script number.
  * It will then apply any missing scripts sequentially, with a progress display for the user.

**Step 7: Backup Reminder**

  * Notify users if no recent backup is found.
  * Provide a way to schedule periodic backup reminders.
