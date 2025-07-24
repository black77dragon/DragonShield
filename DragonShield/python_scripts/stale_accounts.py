from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional

@dataclass
class Account:
    name: str
    earliest_instrument_last_updated_at: datetime | None


def top_stale_accounts(accounts: List[Account]) -> List[Account]:
    def sort_key(a: Account):
        return a.earliest_instrument_last_updated_at or datetime.max

    return sorted(accounts, key=sort_key)


def bucket(date: Optional[datetime], now: Optional[datetime] = None) -> Optional[str]:
    if date is None:
        return None
    if now is None:
        now = datetime.now()
    days = (now - date).days
    if days > 60:
        return "red"
    if days > 30:
        return "amber"
    return "green"
