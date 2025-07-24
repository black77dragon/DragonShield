from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional

@dataclass
class Account:
    name: str
    earliest_instrument_last_updated_at: Optional[datetime]


def top_stale_accounts(accounts: List[Account], limit: int = 10) -> List[Account]:
    def sort_key(a: Account):
        return a.earliest_instrument_last_updated_at or datetime.max

    return sorted(accounts, key=sort_key)[:limit]


def age_bucket(date: Optional[datetime], now: Optional[datetime] = None) -> str:
    if date is None:
        return "red"
    if now is None:
        now = datetime.now()
    delta = (now - date).days
    if delta > 60:
        return "red"
    if delta > 30:
        return "amber"
    return "green"

__all__ = ["Account", "top_stale_accounts", "age_bucket"]
