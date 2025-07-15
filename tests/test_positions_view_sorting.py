from pathlib import Path

POSITIONS_VIEW = Path(__file__).resolve().parents[1] / 'DragonShield' / 'Views' / 'PositionsView.swift'


def test_value_columns_have_sorting():
    text = POSITIONS_VIEW.read_text(encoding='utf-8')
    assert 'sortUsing: PositionValueOriginalComparator' in text
    assert 'sortUsing: PositionValueCHFComparator' in text
