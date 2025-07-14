from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'DragonShield' / 'Views'


def test_transaction_types_preview_exists():
    text = (ROOT / 'TransactionTypesView.swift').read_text(encoding='utf-8')
    assert '#Preview {' in text
    assert 'TransactionTypesView()' in text


def test_portfolio_view_preview_exists():
    text = (ROOT / 'PortfolioView.swift').read_text(encoding='utf-8')
    assert '#Preview {' in text
    assert 'PortfolioView()' in text
