from datetime import datetime, timedelta

from DragonShield.python_scripts.stale_accounts import Account, top_stale_accounts


def test_sort_and_order():
    today = datetime(2025, 1, 1)
    accounts = [
        Account("A", today - timedelta(days=40)),
        Account("B", today - timedelta(days=10)),
        Account("C", today - timedelta(days=20)),
        Account("D", today - timedelta(days=5)),
        Account("E", today - timedelta(days=60)),
        Account("F", today - timedelta(days=15)),
        Account("G", today - timedelta(days=25)),
        Account("H", today - timedelta(days=35)),
        Account("I", today - timedelta(days=45)),
        Account("J", today - timedelta(days=50)),
        Account("K", today - timedelta(days=55)),
    ]

    accounts.append(Account("AA", today - timedelta(days=10)))

    result = top_stale_accounts(accounts)

    assert len(result) == len(accounts)
    dates = [acc.earliest_instrument_last_updated_at for acc in result]
    assert dates == sorted(dates)
    # ensure tie-breaking by name when dates match
    b_index = next(i for i, acc in enumerate(result) if acc.name == "B")
    aa_index = next(i for i, acc in enumerate(result) if acc.name == "AA")
    assert aa_index < b_index
