"""Shared logic for saving what the app sends (readings, entries).

Principles
  * one bad item never blocks a batch: every item gets its own result;
  * the client's id is the key, so sending the same item twice saves it once;
  * the numbers come from the rule tables (loaded from the app), never from this file.
"""
from __future__ import annotations

import json
import math
import re
import time
from typing import Any, Optional

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .models import Crew, FieldDef, InputLimit, MetricDef, ZoneBand

DEFAULT_CREW = "c1"                  # ContractIdentity.crewId (until sign-in decides it)
MAX_BATCH = 500
FUTURE_SKEW_MS = 5 * 60 * 1000       # clocks may be a little ahead
MIN_TIME_MS = 946_684_800_000        # 2000-01-01
SECONDS_LOOKING_LIKE_MS = 100_000_000_000
QUALITIES = {"ok", "stale", "suspect"}
SOURCE_KINDS = {"device", "manual"}
MAX_CONTEXT_CHARS = 2_000
MAX_PAYLOAD_CHARS = 20_000


def now_ms() -> int:
    return int(time.time() * 1000)


def norm_unit(u: Any) -> str:
    return re.sub(r"\s+", "", str(u)).lower()


def is_num(v: Any) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def is_int(v: Any) -> bool:
    return (isinstance(v, int) and not isinstance(v, bool)) or (isinstance(v, float) and v.is_integer())


class RuleCache:
    """The rule tables, read once per request."""

    def __init__(self, db: Session):
        self.metrics = {m.api_metric: m for m in db.scalars(select(MetricDef))}
        self.limits = {r.series_key: r for r in db.scalars(select(InputLimit))}
        self.zone_extent = {k: (lo, hi) for k, lo, hi in db.execute(
            select(ZoneBand.series_key, func.min(ZoneBand.from_value), func.max(ZoneBand.to_value))
            .group_by(ZoneBand.series_key))}
        self.crew_ids = set(db.scalars(select(Crew.id)))
        self.field_ids = set(db.scalars(select(FieldDef.id)))

    def bounds(self, series_key: str) -> Optional[tuple[float, float, str]]:
        """(min, max, label) a value of this series may have. None = no range known."""
        lim = self.limits.get(series_key)
        if lim:
            return lim.min_value, lim.max_value, lim.label
        ext = self.zone_extent.get(series_key)       # e.g. mood has zones but no limit
        return (ext[0], ext[1], series_key) if ext else None


def as_items(body: Any, wrap_key: str) -> list:
    """Accept one object, a list of objects, or {"<wrap_key>": [...]}."""
    if isinstance(body, list):
        items = body
    elif isinstance(body, dict) and isinstance(body.get(wrap_key), list):
        items = body[wrap_key]
    elif isinstance(body, dict):
        items = [body]
    else:
        raise HTTPException(422, "body must be an object or a list of objects")
    if not items:
        raise HTTPException(422, "no items were sent")
    if len(items) > MAX_BATCH:
        raise HTTPException(422, f"too many items in one request (max {MAX_BATCH})")
    return items


def _check_time(value: Any, name: str, errors: list) -> Optional[int]:
    if not is_num(value) or not is_int(value):
        errors.append(f"{name} must be a whole number of UTC epoch milliseconds")
        return None
    t = int(value)
    if t < MIN_TIME_MS:
        errors.append(f"{name} must be UTC epoch milliseconds (this looks like seconds)"
                      if t < SECONDS_LOOKING_LIKE_MS else f"{name} is too far in the past")
        return None
    if t > now_ms() + FUTURE_SKEW_MS:
        errors.append(f"{name} is in the future")
        return None
    return t


def _check_id(raw: dict, errors: list) -> Optional[str]:
    rid = raw.get("id")
    if not isinstance(rid, str) or not rid.strip() or len(rid) > 80:
        errors.append("id is required (text, 1-80 characters)")
        return None
    return rid


def _check_seq(raw: dict, errors: list) -> int:
    seq = raw.get("seq", 0)
    if not is_int(seq) or seq < 0:
        errors.append("seq must be a whole number, 0 or more")
        return 0
    return int(seq)


def _check_crew(raw: dict, cache: RuleCache, errors: list) -> str:
    crew = raw.get("crew_id", DEFAULT_CREW)
    if not isinstance(crew, str) or crew not in cache.crew_ids:
        errors.append(f"unknown crew_id {crew!r}")
    return crew if isinstance(crew, str) else DEFAULT_CREW


def validate_reading(raw: Any, cache: RuleCache) -> tuple[list, Optional[dict]]:
    """-> (errors, columns for the Reading row). No errors means safe to save."""
    if not isinstance(raw, dict):
        return ["each reading must be an object"], None
    errors: list[str] = []
    rid = _check_id(raw, errors)
    seq = _check_seq(raw, errors)
    crew = _check_crew(raw, cache, errors)

    metric = raw.get("metric")
    mdef = cache.metrics.get(metric) if isinstance(metric, str) else None
    if mdef is None:
        errors.append(f"unknown metric {metric!r}")

    value = raw.get("value")
    if not is_num(value):
        errors.append("value must be a number")
        value = None
    t = _check_time(raw.get("time"), "time", errors)

    field = unit = None
    if mdef is not None:
        field = raw.get("field") or mdef.field
        if field != mdef.field:
            errors.append(f"field for {metric} must be '{mdef.field}', got {field!r}")
        unit = raw.get("unit") or mdef.unit
        if norm_unit(unit) != norm_unit(mdef.unit):
            errors.append(f"unit for {metric} must be '{mdef.unit}', got {unit!r}")
        if value is not None:
            b = cache.bounds(mdef.series_key)
            if b and not (b[0] <= value <= b[1]):
                errors.append(f"{b[2]} must be between {b[0]:g} and {b[1]:g} (got {value:g}).")
            elif not b and value < 0:
                errors.append(f"{mdef.name} cannot be negative.")

    quality = raw.get("quality", "ok")
    if quality not in QUALITIES:
        errors.append("quality must be ok, stale or suspect")

    src = raw.get("source", {})
    if not isinstance(src, dict):
        errors.append("source must be an object")
        src = {}
    kind = src.get("kind", "device")
    if kind not in SOURCE_KINDS:
        errors.append("source.kind must be device or manual")
    for k, n in (("device", 80), ("route", 80), ("type", 20)):
        if not isinstance(src.get(k, ""), str) or len(src.get(k, "")) > n:
            errors.append(f"source.{k} must be text of at most {n} characters")

    ctx = raw.get("context", {})
    if not isinstance(ctx, dict) or len(json.dumps(ctx, default=str)) > MAX_CONTEXT_CHARS:
        errors.append("context must be an object under 2000 characters")
        ctx = {}

    # The app sends blood pressure as one reading (systolic); diastolic may ride along in context.
    if mdef is not None and metric == "blood_pressure" and "diastolic" in ctx:
        dia = ctx["diastolic"]
        b = cache.bounds("dia")
        if not is_num(dia):
            errors.append("context.diastolic must be a number")
        elif b and not (b[0] <= dia <= b[1]):
            errors.append(f"{b[2]} must be between {b[0]:g} and {b[1]:g} (got {dia:g}).")
        elif value is not None and dia >= value:
            errors.append("Diastolic must be lower than systolic.")

    if errors:
        return errors, None
    return [], dict(
        id=rid, seq=seq, crew_id=crew, metric=metric, field=field, value=float(value), unit=mdef.unit,
        time_ms=t, source_kind=kind, source_device=src.get("device", ""), source_route=src.get("route", ""),
        source_type=src.get("type", "direct"), quality=quality, context_json=ctx, received_ms=now_ms())


def validate_entry(raw: Any, cache: RuleCache) -> tuple[list, Optional[dict]]:
    if not isinstance(raw, dict):
        return ["each entry must be an object"], None
    errors: list[str] = []
    rid = _check_id(raw, errors)
    seq = _check_seq(raw, errors)
    crew = _check_crew(raw, cache, errors)
    field = raw.get("field")
    if not isinstance(field, str) or field not in cache.field_ids:
        errors.append(f"unknown field {field!r}")
    ts = _check_time(raw.get("ts"), "ts", errors)
    payload = raw.get("payload", {})
    if not isinstance(payload, dict):
        errors.append("payload must be an object")
    elif len(json.dumps(payload, default=str)) > MAX_PAYLOAD_CHARS:
        errors.append("payload is too large (max 20000 characters)")
    if errors:
        return errors, None
    return [], dict(id=rid, seq=seq, crew_id=crew, field=field, payload_json=payload, ts_ms=ts,
                    received_ms=now_ms())


def store(db: Session, model, values: dict) -> str:
    """Insert one row. -> 'accepted' | 'duplicate' | 'failed'."""
    if db.get(model, values["id"]) is not None:
        return "duplicate"
    try:
        with db.begin_nested():
            db.add(model(**values))
            db.flush()
    except IntegrityError:
        return "duplicate" if db.get(model, values["id"]) is not None else "failed"
    return "accepted"


def ingest(db: Session, body: Any, wrap_key: str, model, validator) -> dict:
    """Validate and save every item; return a per-item report."""
    items = as_items(body, wrap_key)
    cache = RuleCache(db)
    results, seen = [], set()
    for raw in items:
        errors, values = validator(raw, cache)
        rid = raw.get("id") if isinstance(raw, dict) else None
        if errors:
            results.append({"id": rid, "status": "rejected", "errors": errors})
            continue
        if values["id"] in seen:
            results.append({"id": values["id"], "status": "duplicate"})
            continue
        seen.add(values["id"])
        status = store(db, model, values)
        if status == "failed":
            results.append({"id": values["id"], "status": "rejected", "errors": ["could not be saved"]})
        else:
            results.append({"id": values["id"], "status": status})
    db.commit()
    count = lambda s: sum(1 for r in results if r["status"] == s)  # noqa: E731
    return {"accepted": count("accepted"), "duplicates": count("duplicate"), "rejected": count("rejected"),
            "results": results}
