from pathlib import Path

VIEW = Path(__file__).resolve().parents[1] / 'DragonShield' / 'Views' / 'AllocationTargetsTableView.swift'

def _view_text():
    return VIEW.read_text(encoding='utf-8')

def test_pencil_is_visible():
    text = _view_text()
    assert 'pencil.circle' in text
    assert '.accessibilityLabel("Edit targets for' in text

def test_double_click_opens_panel():
    text = _view_text()
    assert '.onTapGesture(count: 2)' in text


def test_keyboard_enter_opens_panel():
    text = _view_text()
    assert '.onKeyDown(.enter' in text
