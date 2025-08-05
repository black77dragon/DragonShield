import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

from deploy_db import parse_version

def test_schema_version_updated():
    schema_path = Path(__file__).resolve().parents[1] / 'DragonShield' / 'database' / 'schema.sql'
    assert parse_version(str(schema_path)) == '4.20'
