import re
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException


def range_start(range_str: str) -> datetime:
    """'24h' / '7d' / '30d' -> datetime (UTC) that far in the past."""
    m = re.fullmatch(r"(\d{1,4})([hd])", range_str)
    if not m:
        raise HTTPException(422, "range must look like '24h' or '7d'")
    n, unit = int(m.group(1)), m.group(2)
    delta = timedelta(hours=n) if unit == "h" else timedelta(days=n)
    return datetime.now(timezone.utc) - delta
