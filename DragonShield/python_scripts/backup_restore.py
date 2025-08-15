#!/usr/bin/env python3
"""Enhanced DragonShield backup with safety feature integration.

This is a drop-in replacement for your existing backup_restore.py that integrates
with the safety features installed by migration 008_add_backup_restore_safety.sql.

Key improvements:
- Pre-backup validation using safety views
- Enhanced integrity checking
- Comprehensive validation reporting
- Seamless integration with existing Swift BackupService
"""

import argparse
import json
import os
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Tuple


class SafetyValidationResult:
    """Encapsulates validation results from safety features."""

    def __init__(self, db_path: str):
        self.db_path = db_path
        self.summary = {}
        self.validation_issues = []
        self.duplicate_conflicts = []
        self.foreign_key_violations = []
        self.has_critical_issues = False
        self.has_warnings = False

    def run_validation(self) -> None:
        """Run comprehensive validation using installed safety features."""
        try:
            with sqlite3.connect(self.db_path) as conn:
                # 1. Check if safety features are installed
                safety_check = conn.execute("""
                    SELECT COUNT(*) FROM sqlite_master
                    WHERE name IN ('InstrumentsBackup', 'InstrumentsValidationReport',
                                  'InstrumentsDuplicateCheck', 'RestoreValidationSummary')
                """).fetchone()[0]

                if safety_check < 4:
                    self.validation_issues.append({
                        'type': 'missing_safety_features',
                        'message': f'Only {safety_check}/4 safety features installed',
                        'severity': 'warning'
                    })
                    self.has_warnings = True
                    return

                # 2. Get overall validation summary
                try:
                    summary_row = conn.execute("SELECT * FROM RestoreValidationSummary").fetchone()
                    if summary_row:
                        self.summary = {
                            'table_name': summary_row[0],
                            'total_records': summary_row[1],
                            'valid_records': summary_row[2],
                            'invalid_records': summary_row[3],
                            'pending_records': summary_row[4],
                            'duplicate_conflicts': summary_row[5]
                        }

                        if self.summary['invalid_records'] > 0:
                            self.has_critical_issues = True
                        if self.summary['duplicate_conflicts'] > 0:
                            self.has_warnings = True
                except sqlite3.Error as e:
                    self.validation_issues.append({
                        'type': 'summary_error',
                        'message': f'Could not get validation summary: {e}',
                        'severity': 'warning'
                    })

                # 3. Get specific validation issues
                try:
                    issues = conn.execute("SELECT * FROM InstrumentsValidationReport").fetchall()
                    for issue in issues:
                        self.validation_issues.append({
                            'type': 'instrument_validation',
                            'instrument_id': issue[0],
                            'instrument_name': issue[1],
                            'isin': issue[2],
                            'valor_nr': issue[3],
                            'validation_status': issue[4],
                            'subclass_issue': issue[5],
                            'currency_issue': issue[6],
                            'severity': 'error' if issue[4] == 'invalid' else 'warning'
                        })
                        if issue[4] == 'invalid':
                            self.has_critical_issues = True
                except sqlite3.Error as e:
                    self.validation_issues.append({
                        'type': 'check_failed',
                        'message': f'Could not query InstrumentsValidationReport: {e}',
                        'severity': 'warning'
                    })
                    self.has_warnings = True


                # 4. Get duplicate conflicts
                try:
                    duplicates = conn.execute("SELECT * FROM InstrumentsDuplicateCheck").fetchall()
                    for dup in duplicates:
                        self.duplicate_conflicts.append({
                            'conflict_type': dup[0],
                            'conflicting_value': dup[1],
                            'duplicate_count': dup[2],
                            'affected_instruments': dup[3]
                        })
                        self.has_warnings = True
                except sqlite3.Error as e:
                    self.validation_issues.append({
                        'type': 'check_failed',
                        'message': f'Could not query InstrumentsDuplicateCheck: {e}',
                        'severity': 'warning'
                    })
                    self.has_warnings = True

                # 5. Check foreign key integrity
                try:
                    conn.execute("PRAGMA foreign_keys = ON")
                    fk_violations = conn.execute("PRAGMA foreign_key_check").fetchall()
                    for violation in fk_violations:
                        self.foreign_key_violations.append({
                            'table': violation[0],
                            'rowid': violation[1],
                            'parent_table': violation[2],
                            'constraint_index': violation[3]
                        })
                        self.has_critical_issues = True
                except sqlite3.Error as e:
                    self.validation_issues.append({
                        'type': 'check_failed',
                        'message': f'Could not perform foreign key check: {e}',
                        'severity': 'warning'
                    })
                    self.has_warnings = True

        except sqlite3.Error as e:
            self.validation_issues.append({
                'type': 'database_error',
                'message': f'Database validation failed: {e}',
                'severity': 'error'
            })
            self.has_critical_issues = True

    def to_dict(self) -> Dict[str, Any]:
        """Convert validation results to dictionary for JSON serialization."""
        return {
            'summary': self.summary,
            'validation_issues': self.validation_issues,
            'duplicate_conflicts': self.duplicate_conflicts,
            'foreign_key_violations': self.foreign_key_violations,
            'has_critical_issues': self.has_critical_issues,
            'has_warnings': self.has_warnings,
            'total_issues': len(self.validation_issues) + len(self.duplicate_conflicts) + len(
                self.foreign_key_violations)
        }


def _row_counts(conn: sqlite3.Connection) -> Dict[str, int]:
    """Get row counts for all tables."""
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [r[0] for r in cur.fetchall()]
    counts = {}
    for tbl in tables:
        cur = conn.execute(f'SELECT COUNT(*) FROM "{tbl}";')
        counts[tbl] = cur.fetchone()[0]
    return counts


def _verify_and_counts(path: Path) -> Dict[str, int]:
    """Run PRAGMA integrity_check and return table row counts.

    Raises RuntimeError if the database is corrupt or cannot be opened.
    """
    try:
        with sqlite3.connect(path) as conn:
            # Basic integrity check
            if conn.execute("PRAGMA integrity_check;").fetchone()[0] != "ok":
                raise RuntimeError("Basic integrity check failed")

            # Enhanced integrity check with safety features if available
            safety_check = conn.execute("""
                SELECT COUNT(*) FROM sqlite_master
                WHERE name = 'RestoreValidationSummary' AND type = 'view'
            """).fetchone()[0]

            if safety_check > 0:
                # Safety features available - run enhanced validation
                validation = SafetyValidationResult(str(path))
                validation.run_validation()

                if validation.has_critical_issues:
                    error_details = []
                    # Check for instrument validation errors
                    for issue in validation.validation_issues:
                        if issue.get('severity') == 'error':
                            error_details.append(
                                f"Instrument Error: ID {issue.get('instrument_id')} - "
                                f"{issue.get('subclass_issue') or issue.get('currency_issue')}"
                            )

                    # Check for foreign key violations
                    for violation in validation.foreign_key_violations:
                        error_details.append(
                            f"Foreign Key Violation in table '{violation.get('table')}': "
                            f"rowid {violation.get('rowid')} has a broken link to table '{violation.get('parent_table')}'."
                        )

                    if not error_details:  # Fallback for other critical errors
                        error_details.append("An unspecified critical issue was found during validation.")

                    raise RuntimeError(f"Enhanced integrity check failed: {'; '.join(error_details)}")

            return _row_counts(conn)

    except sqlite3.Error as e:
        raise RuntimeError(f"Database integrity check failed: {e}") from e


def backup_database(
        db_path: Path, dest_dir: Path, env: str
) -> Tuple[Path, Dict[str, int], Dict[str, Any]]:
    """Enhanced backup with safety validation.

    Returns:
        Tuple of (backup_path, row_counts, validation_report)
    """
    dest_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = dest_dir / f"{env}_backup_{ts}.sqlite"
    manifest_path = backup_path.with_suffix(".manifest.json")

    # 1. Pre-backup validation
    print("🔍 Running pre-backup safety validation...")
    validation = SafetyValidationResult(str(db_path))
    validation.run_validation()
    validation_report = validation.to_dict()

    # 2. Report validation issues
    if validation.has_critical_issues:
        critical_count = len(validation.foreign_key_violations) + len([i for i in validation.validation_issues if i.get('severity') == 'error'])
        print(f"⚠️  WARNING: {critical_count} critical validation issues found")
    if validation.has_warnings:
        print(f"⚠️  WARNING: {validation_report['total_issues']} total issues found")

    # 3. Create atomic backup using SQLite's backup API
    print(f"💾 Creating atomic backup: {backup_path}")
    with sqlite3.connect(db_path) as src, sqlite3.connect(backup_path) as dst:
        src.backup(dst)

    # 4. Verify backup integrity
    try:
        counts = _verify_and_counts(backup_path)
    except Exception:
        backup_path.unlink(missing_ok=True)
        raise

    # 5. Create comprehensive manifest
    manifest = {
        'backup_info': {
            'timestamp': ts,
            'source_db': str(db_path),
            'backup_file': str(backup_path),
            'environment': env
        },
        'row_counts': counts,
        'validation_report': validation_report,
        'backup_verification': {
            'integrity_check': 'PASSED',
            'safety_features': 'DETECTED' if validation_report.get('summary') else 'NOT_DETECTED'
        }
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    print("✅ Backup completed successfully!")
    if validation.has_warnings or validation.has_critical_issues:
        print(f"📄 Validation report saved to: {manifest_path}")

    return backup_path, counts, validation_report


def restore_database(db_path: Path, backup_file: Path) -> Dict[str, Tuple[int, int]]:
    """Enhanced restore with safety validation.

    Returns:
        Dictionary mapping table names to (pre_count, post_count) tuples
    """
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    old_path = db_path.with_name(db_path.name + f".old.{ts}")

    # 1. Verify backup file integrity
    print("🔍 Verifying backup file...")
    try:
        _verify_and_counts(backup_file)
    except RuntimeError as e:
        # Re-raise to ensure a problematic backup is never restored
        raise RuntimeError(f"CRITICAL: Backup file '{backup_file.name}' failed integrity check and cannot be restored. Reason: {e}")


    # 2. Check manifest for known issues
    manifest_path = backup_file.with_suffix('.manifest.json')
    if manifest_path.exists():
        print("📄 Reading backup manifest...")
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
            validation_report = manifest.get('validation_report', {})

            if validation_report.get('has_critical_issues', False):
                print("⚠️  WARNING: Backup manifest reports critical issues.")
                print("⚠️  Proceeding with restore, but caution is advised...")

    # 3. Get pre-restore counts and create emergency backup
    with sqlite3.connect(db_path) as conn:
        pre_counts = _row_counts(conn)

    print(f"💾 Creating emergency backup: {old_path}")
    os.replace(db_path, old_path)

    try:
        # 4. Perform restore
        print("🔄 Restoring database...")
        shutil.copy2(backup_file, db_path)

        # 5. Post-restore validation
        print("🔍 Running post-restore validation...")
        post_counts = _verify_and_counts(db_path)

        # 6. Run safety validation on restored database
        validation = SafetyValidationResult(str(db_path))
        validation.run_validation()

        if validation.has_critical_issues:
            print("⚠️  WARNING: Restored database has critical validation issues.")
        else:
            print("✅ Post-restore validation passed")

        # 7. Create restore summary
        summary = {}
        for table in sorted(set(pre_counts) | set(post_counts)):
            pre = pre_counts.get(table, 0)
            post = post_counts.get(table, 0)
            summary[table] = (pre, post)

        print("✅ Restore completed successfully!")
        print(f"📁 Emergency backup saved: {old_path}")

        return summary

    except Exception as e:
        print(f"❌ Restore failed: {e}")
        print("🔄 Rolling back to original database...")
        if old_path.exists():
            os.replace(old_path, db_path)
        raise


def main(argv=None) -> int:
    """Main entry point with enhanced safety integration."""
    parser = argparse.ArgumentParser(
        description="Enhanced backup/restore for DragonShield with safety features"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("backup", help="Create a backup with safety validation")
    b.add_argument("db", type=Path, help="Path to dragonshield.sqlite")
    b.add_argument("dest", type=Path, help="Directory for backup file")
    b.add_argument("--env", type=str, default="prod", help="Environment label (e.g., prod, test)")

    r = sub.add_parser("restore", help="Restore from backup with safety checks")
    r.add_argument("db", type=Path, help="Path to dragonshield.sqlite")
    r.add_argument("backup", type=Path, help="Backup file to restore")

    v = sub.add_parser("validate", help="Run safety validation only")
    v.add_argument("db", type=Path, help="Path to dragonshield.sqlite")

    args = parser.parse_args(argv)

    try:
        if args.cmd == "backup":
            backup_path, counts, validation_report = backup_database(args.db, args.dest, args.env)

            # Output for Swift BackupService integration
            print("\n📊 Backup Summary")
            print(f"{'Table':<25}{'Rows'}")
            print("-" * 30)
            for tbl, cnt in sorted(counts.items()):
                print(f"{tbl:<25}{cnt}")
            print(f"\nBackup created at {backup_path}")

            # Output validation summary for UI integration
            if validation_report.get('has_warnings') or validation_report.get('has_critical_issues'):
                print(f"\n⚠️  Validation Summary:")
                print(f"   Total Issues: {validation_report.get('total_issues', 0)}")
                print(f"   Critical: {validation_report.get('has_critical_issues', False)}")

            return 0

        elif args.cmd == "restore":
            summary = restore_database(args.db, args.backup)

            print("\n📊 Restore Summary")
            print(f"{'Table':<25}{'Pre-Restore':<15}{'Post-Restore':<15}Delta")
            print("-" * 60)
            for tbl, (pre, post) in sorted(summary.items()):
                delta = post - pre
                sign = "+" if delta >= 0 else ""
                print(f"{tbl:<25}{pre:<15}{post:<15}{sign}{delta}")
            return 0

        elif args.cmd == "validate":
            validation = SafetyValidationResult(str(args.db))
            validation.run_validation()

            print("\n📊 Validation Report")
            print(json.dumps(validation.to_dict(), indent=2))

            if validation.has_critical_issues:
                return 1  # Exit code for critical issues
            return 0

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
