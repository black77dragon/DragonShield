from dataclasses import dataclass
from datetime import datetime
from typing import List

@dataclass
class Account:
    name: str
    earliest_instrument_last_updated_at: datetime | None


def top_stale_accounts(accounts: List[Account]) -> List[Account]:
    def sort_key(a: Account):
        return (
            a.earliest_instrument_last_updated_at or datetime.max,
            a.name.lower(),
        )

    return sorted(accounts, key=sort_key)
