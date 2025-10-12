````markdown
# Database Management Concept

## Overview

We’ve adopted **dbmate** to manage our SQLite schema changes in a clean, repeatable, incremental way. Previously we kept one giant `schema.sql` and manually copied patches back in—this quickly became unmanageable. Now:

- **dbmate** drives migrations
- All schema–changers live in `db/migrations/`
- We squash historical changes into a single **baseline**
- Future changes are tiny, focused SQL files

---

## Tools

- **SQLite 3** — our production database
- **dbmate** — lightweight migration runner
- **git** — version control
- **VS Code / Xcode** — editor of choice
- **DB Browser for SQLite** (optional) — GUI for ad-hoc inspection

---

## Folder Layout

    DragonShield/
    ├── db/
    │   └── migrations/
    │       ├── 001_baseline_schema.sql
    │       ├── 002_add_… .sql
    │       └── 003_modify_… .sql
    ├── src/         ← application code
    └── .env         ← DATABASE_URL, etc.

- **001_baseline_schema.sql**
  Consolidated dump of all `CREATE TABLE`, `CREATE VIEW`, `CREATE TRIGGER`, etc.
- **00X_*.sql**
  Each file begins with:

    -- migrate:up
    <your ALTER / CREATE / DROP statements here>
    -- migrate:down
    <rollback statements here>

- Files are applied in lexical order.

---

## Getting Started

1. **Install dbmate**

       brew install dbmate

2. **Configure your `.env`**

       export DATABASE_URL="sqlite:///Users/renekeller/.../dragonshield.sqlite"

3. **Initialize migrations folder**

       mkdir -p db/migrations

4. **Create baseline schema**

       sqlite3 "$DATABASE_URL" .schema \
         | sed '1 i\-- migrate:up' \
         | sed '$ a\-- migrate:down' \
         > db/migrations/001_baseline_schema.sql

   Edit out any transient tables (e.g. `sqlite_sequence`).

5. **Mark baseline as applied**

       sqlite3 "$DATABASE_URL" <<SQL
       DELETE FROM schema_migrations;
       INSERT INTO schema_migrations(version) VALUES('001_baseline_schema.sql');
       SQL

6. **Verify**

       dbmate --migrations-dir ./db/migrations --url "$DATABASE_URL" status
       # Should report “✓ 001_baseline_schema.sql”

---

## Creating a New Migration

1. **Generate a new SQL file**
   Name it `00X_descriptive_name.sql` (increment X sequentially).

2. **Add migrate markers**
   ```sql
   -- migrate:up
   ALTER TABLE ...
   -- migrate:down
   ALTER TABLE ... DROP COLUMN ...
   ````

3. **Run migrations**

   ```
   dbmate --migrations-dir ./db/migrations --url "$DATABASE_URL" up
   ```

4. **Commit to git**

   ```
   git add db/migrations/00X_*.sql
   git commit -m "feat(db): add descriptive change"
   git push
   ```

---

## Rolling Back

To undo the last migration:

```
dbmate --migrations-dir ./db/migrations --url "$DATABASE_URL" down
```

---

## Archiving Old Migrations (Establishing a New Baseline)

1. **Archive existing files**

   ```
   mkdir db/migrations_archive
   mv db/migrations/*.sql db/migrations_archive/
   ```

2. **Dump current schema**

   ```
   sqlite3 "$DATABASE_URL" .schema > db/migrations/001_baseline_schema.sql
   ```

   Wrap it in migrate markers and remove transient bits.

3. **Reset schema_migrations**

   ```
   sqlite3 "$DATABASE_URL" <<SQL
   DELETE FROM schema_migrations;
   INSERT INTO schema_migrations(version) VALUES('001_baseline_schema.sql');
   SQL
   ```

4. **Verify**

   ```
   dbmate --migrations-dir ./db/migrations --url "$DATABASE_URL" status
   # Should report “✓ 001_baseline_schema.sql”
   ```

---

## Why This Matters

* **Reproducibility**
  Spin up a fresh DB from `001_baseline_schema.sql` + later migrations.
* **Clarity**
  Each change lives in its own file with clear up/down logic.
* **Versioned**
  Git tracks every schema tweak.
* **Safe rollbacks**
  dbmate enforces matching migrate:up / migrate:down.

---

## Best Practices

* Keep `db/migrations/` in your repo root.
* Never edit old migrations once deployed to production.
* Test both `up` and `down` locally before merging.
* Use descriptive filenames:

  ```
  002_add_class_targets_table.sql
  003_add_subclass_targets_table.sql
  004_add_validation_triggers.sql
  ```
````
