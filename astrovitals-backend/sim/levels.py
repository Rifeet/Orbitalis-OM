"""The app's own level logic in Python, so simulated data can be checked against the rules.

Mirrors zones.dart zoneLevel() and engine.dart mv()/lv():
  * a value in [from, to) gets that band's level; outside the table it clamps to the end band;
  * blood pressure = worse of systolic and diastolic; body mass = % change from 74 kg;
  * cumulative radiation = % of the environment's mission limit;
  * radiation dose rate = ratio to the environment's expected rate (rule_meta bands).
"""
from __future__ import annotations

import json
from pathlib import Path

RULES_PATH = Path(__file__).resolve().parent.parent / "app" / "rules" / "rules_data.json"
BASE_MASS_KG = 74.0   # kBase['mass']


def load_rules() -> dict:
    return json.loads(RULES_PATH.read_text(encoding="utf-8"))


class Levels:
    def __init__(self, rules: dict | None = None):
        self.rules = rules or load_rules()
        self.zones = {k: z["bands"] for k, z in self.rules["zones"].items()}
        self.env = {e["key"]: e for e in self.rules["environments"]}
        self.series = {m["api_metric"]: m["series_key"] for m in self.rules["metrics"]}
        self.rate_bands = self.rules["meta"]["radiation_rate_bands"]

    def zone(self, series: str, v: float) -> int:
        z = self.zones[series]
        for lo, hi, lvl in z:
            if lo <= v < hi:
                return lvl
        return z[0][2] if v < z[0][0] else z[-1][2]

    def dose_rate_level(self, mSv_per_day: float, env: str = "iss") -> int:
        ratio = mSv_per_day / self.env[env]["dose_rate_msv_day"]
        for lo, hi, lvl in self.rate_bands:
            if ratio >= lo and (hi is None or ratio < hi):
                return lvl
        return 0

    def reading_level(self, api_metric: str, value: float, context: dict | None = None, env: str = "iss") -> int:
        ctx = context or {}
        if api_metric == "dose_rate":
            return self.dose_rate_level(value, env)
        if api_metric == "cumulative_dose":
            return self.zone("rad", value / self.env[env]["limit_msv"] * 100)
        if api_metric == "body_mass":
            return self.zone("mass", (value - BASE_MASS_KG) / BASE_MASS_KG * 100)
        if api_metric == "blood_pressure":
            lvl = self.zone("sys", value)
            if isinstance(ctx.get("diastolic"), (int, float)):
                lvl = max(lvl, self.zone("dia", ctx["diastolic"]))
            return lvl
        return self.zone(self.series[api_metric], value)


def tier_of(lvl: int) -> int:
    """engine.dart tierOf()."""
    return 0 if lvl <= 0 else lvl if lvl <= 2 else 3 if lvl <= 4 else 4
