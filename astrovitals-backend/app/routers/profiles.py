from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import (Baseline, DeviceSpec, EnvProfile, FieldDef, InputLimit, MetricDef, RuleMeta, ZoneBand,
                      ZoneTable)

router = APIRouter(prefix="/v1", tags=["profiles"])


def build_profiles(db: Session) -> dict:
    """The app's rules, in the same names the Flutter models use (EnvProfile, MetricDef, ZoneTable, LimRule...)."""
    meta = {m.key: m.value_json for m in db.scalars(select(RuleMeta))}
    bands: dict[str, list] = {}
    for b in db.scalars(select(ZoneBand).order_by(ZoneBand.series_key, ZoneBand.band_order)):
        bands.setdefault(b.series_key, []).append([b.from_value, b.to_value, b.level])
    return {
        "version": meta.get("source_sha256", ""),
        "environments": [
            {"key": e.key, "n": e.name, "endA": e.end_a, "endB": e.end_b, "total": e.total_days, "day": e.day,
             "g": e.gravity, "dose": e.dose_rate_msv_day, "limit": e.limit_msv, "delayMin": e.delay_min,
             "phase": e.phase}
            for e in db.scalars(select(EnvProfile).order_by(EnvProfile.key))],
        "metrics": [
            {"id": m.id, "api": m.api_metric, "field": m.field, "name": m.name, "unit": m.unit,
             "key": m.series_key, "decimals": m.decimals}
            for m in db.scalars(select(MetricDef).order_by(MetricDef.id))],
        "fields": [{"id": f.id, "hz": f.hz, "label": f.label, "kind": f.kind, "log": f.log}
                   for f in db.scalars(select(FieldDef).order_by(FieldDef.id))],
        "zones": {z.series_key: {"bar": None if z.bar_min is None else [z.bar_min, z.bar_max],
                                 "z": bands.get(z.series_key, [])}
                  for z in db.scalars(select(ZoneTable).order_by(ZoneTable.series_key))},
        "limits": {r.series_key: {"min": r.min_value, "max": r.max_value, "label": r.label, "step": r.step}
                   for r in db.scalars(select(InputLimit))},
        "baselines": {r.series_key: r.value for r in db.scalars(select(Baseline))},
        "devices": {d.series_key: {"device": d.device, "route": d.route, "kind": d.kind, "ageMin": d.age_min}
                    for d in db.scalars(select(DeviceSpec))},
        "plan": {"bed": meta.get("plan_bed"), "up": meta.get("plan_up")},
        "score": meta.get("health_score"),
        "cap": meta.get("health_cap"),
        "tierNames": meta.get("tier_names"),
        "radiationRateBands": meta.get("radiation_rate_bands"),
        "unsentSeries": meta.get("unsent_series", []),
    }


@router.get("/profiles")
def get_profiles(request: Request, response: Response, db: Session = Depends(get_db)):
    """Environment profiles + all rules. Send If-None-Match with the last ETag to get a cheap 304."""
    data = build_profiles(db)
    etag = f'"{data["version"]}"'
    if data["version"] and request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers={"ETag": etag})
    response.headers["ETag"] = etag
    return data
