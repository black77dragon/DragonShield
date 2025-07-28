from pathlib import Path

KEYS_FILE = Path(__file__).resolve().parents[1] / 'DragonShield' / 'helpers' / 'UserDefaultsKeys.swift'

def test_allocation_column_key_present():
    text = KEYS_FILE.read_text(encoding='utf-8')
    assert 'assetAllocationColumnWidths' in text

