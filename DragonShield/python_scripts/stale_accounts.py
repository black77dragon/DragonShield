from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional

@dataclass
class Account:
    name: str
    earliest_instrument_last_updated_at: datetime | None


def top_stale_accounts(accounts: List[Account], limit: Optional[int] = None) -> List[Account]:
    def sort_key(a: Account):
        return a.earliest_instrument_last_updated_at or datetime.max

    sorted_accounts = sorted(accounts, key=sort_key)
    return sorted_accounts[:limit] if limit else sorted_accounts


def bucket_for(date: Optional[datetime], now: datetime | None = None) -> Optional[str]:
    now = now or datetime.now()
    if date is None:
        return None
    days = (now - date).days
    if days > 60:
        return "red"
    if days > 30:
        return "amber"
    return "green"
