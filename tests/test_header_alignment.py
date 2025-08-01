from pathlib import Path

VIEW_FILE = Path(__file__).resolve().parents[1] / 'DragonShield' / 'Views' / 'AllocationTargetsTableView.swift'


def test_header_row_insets_removed():
    text = VIEW_FILE.read_text(encoding='utf-8')
    assert '.listRowInsets(.init())' in text
