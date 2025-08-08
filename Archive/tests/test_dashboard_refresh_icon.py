from pathlib import Path


TILE_FILE = (
    Path(__file__).resolve().parents[1]
    / 'DragonShield' / 'Views' / 'DashboardTiles'
    / 'AccountsNeedingUpdateTile.swift'
)


def test_dashboard_refresh_icon():
    text = TILE_FILE.read_text(encoding='utf-8')
    assert 'arrow.clockwise' in text
    assert 'refreshEarliestInstrumentTimestamps' in text
