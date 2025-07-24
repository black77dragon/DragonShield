from pathlib import Path

ACCOUNTS_VIEW = Path(__file__).resolve().parents[1] / 'DragonShield' / 'Views' / 'AccountsView.swift'


def test_refresh_button_removed():
    text = ACCOUNTS_VIEW.read_text(encoding='utf-8')
    assert 'Refresh Instrument Timestamps' not in text
    assert 'refreshEarliestInstrumentTimestamps' not in text
