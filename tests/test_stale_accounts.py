from datetime import datetime, timedelta

from DragonShield.python_scripts.stale_accounts import Account, top_stale_accounts, age_bucket


def test_sort_and_limit():
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

    result = top_stale_accounts(accounts)

    assert len(result) == 10
    dates = [acc.earliest_instrument_last_updated_at for acc in result]
    assert dates == sorted(dates)


def test_age_bucket_classification():
    today = datetime(2025, 1, 1)
    assert age_bucket(today - timedelta(days=10), today) == "green"
    assert age_bucket(today - timedelta(days=40), today) == "amber"
    assert age_bucket(today - timedelta(days=61), today) == "red"
    assert age_bucket(None, today) == "red"
