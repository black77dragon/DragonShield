#!/usr/bin/env python3
# python_scripts/deploy_db.py
# MARK: - Version 1.0
# MARK: - History
# - 1.0: Initial creation. Copies repo DB to production path.

import os
import shutil


def main() -> None:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_path = os.path.join(script_dir, '..', 'dragonshield.sqlite')
    dest_dir = os.path.expanduser(os.path.join('~', 'Library', 'Application Support', 'DragonShield'))
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, 'dragonshield.sqlite')
    shutil.copy2(source_path, dest_path)
    print(f"Database copied from {source_path} to {dest_path}")


if __name__ == '__main__':
    main()
