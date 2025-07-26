from pathlib import Path

FILE = Path(__file__).resolve().parents[1] / 'DragonShield' / 'Views' / 'DashboardTiles' / 'DashboardTiles.swift'

def test_resize_handle_icon():
    text = FILE.read_text(encoding='utf-8')
    assert 'square.and.arrow.up.right' in text
    assert 'Resize handle for' in text
