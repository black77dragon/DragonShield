from pathlib import Path

HANDLE_FILE = Path(__file__).resolve().parents[1] / 'DragonShield' / 'Views' / 'ResizeHandle.swift'

def test_resize_handle_icon():
    text = HANDLE_FILE.read_text(encoding='utf-8')
    assert 'square.and.arrow.up.right' in text
