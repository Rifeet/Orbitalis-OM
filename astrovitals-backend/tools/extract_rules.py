#!/usr/bin/env python3
"""Extract the app's rules from its Dart source into app/rules/rules_data.json.

The Flutter app is the source of truth for every threshold. This script READS the
Dart files (nothing is retyped by hand) so the backend can never drift by typo.
Re-run it whenever the frontend numbers change:

    python tools/extract_rules.py path/to/astrovitals_src/lib
    python tools/extract_rules.py path/to/astrovitals_src/lib --check   # exit 1 if JSON is stale

Files read: contract/zones.dart, limits.dart, models.dart, fields.dart, engine/engine.dart, data/app_state.dart
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

FILES = ["contract/zones.dart", "contract/limits.dart", "contract/models.dart", "engine/engine.dart",
         "contract/fields.dart", "data/app_state.dart"]
OUT = Path(__file__).resolve().parent.parent / "app" / "rules" / "rules_data.json"
NUM = r"-?\d+(?:\.\d+)?"


def num(s: str):
    f = float(s)
    return int(f) if f == int(f) and "." not in s else f


def need(match, what: str):
    if not match:
        sys.exit(f"extract_rules: could not find {what}. Has the Dart file format changed?")
    return match


def parse_zones(zsrc: str, msrc: str) -> dict:
    lists = {}
    for name, body in re.findall(r"const List<List<double>> (\w+) = \[(.*?)\];", zsrc, re.S):
        lists[name] = [[num(a), num(b), int(c)] for a, b, c in
                       re.findall(rf"\[\s*({NUM})\s*,\s*({NUM})\s*,\s*(\d+)\s*\]", body)]
    block = need(re.search(r"kZoneByKey = \{(.*?)\n\};", msrc, re.S), "kZoneByKey").group(1)
    zones = {}
    for key, table, b0, b1 in re.findall(
            rf"'(\w+)':\s*ZoneTable\((\w+)(?:,\s*bar:\s*\[({NUM}),\s*({NUM})\])?\)", block):
        if table not in lists:
            sys.exit(f"extract_rules: zone list '{table}' for '{key}' not found")
        zones[key] = {"bar": [num(b0), num(b1)] if b0 else None, "bands": lists[table]}
    return zones


def parse_envs(msrc: str) -> list:
    block = need(re.search(r"const List<EnvProfile> kEnvProfiles = \[(.*?)\n\];", msrc, re.S), "kEnvProfiles").group(1)
    out = []
    for body in re.findall(r"EnvProfile\((.*?)\)", block, re.S):
        d = {}
        for k, v in re.findall(rf"(\w+):\s*('[^']*'|{NUM})", body):
            d[k] = v.strip("'") if v.startswith("'") else num(v)
        out.append({
            "key": d["key"], "name": d["n"], "end_a": d["endA"], "end_b": d["endB"],
            "total_days": d["total"], "day": d["day"], "gravity": d["g"],
            "dose_rate_msv_day": float(d["dose"]), "limit_msv": float(d["limit"]),
            "delay_min": float(d["delayMin"]), "phase": d["phase"],
        })
    return out


def parse_metrics(msrc: str) -> list:
    block = need(re.search(r"const List<MetricDef> kMetrics = \[(.*?)\n\];", msrc, re.S), "kMetrics").group(1)
    pat = (r"MetricDef\(\s*'(\w+)',\s*'(\w+)',\s*'(\w+)',\s*'([^']*)',\s*'([^']*)',\s*"
           r"key:\s*'(\w+)'(?:,\s*decimals:\s*(\d+))?\s*\)")
    return [{"id": a, "api_metric": b, "field": c, "name": d, "unit": e, "series_key": f,
             "decimals": int(g) if g else 0} for a, b, c, d, e, f, g in re.findall(pat, block, re.S)]


def parse_limits(lsrc: str) -> dict:
    block = need(re.search(r"kLim = \{(.*?)\n\};", lsrc, re.S), "kLim").group(1)
    pat = rf"'(\w+)':\s*LimRule\(\s*({NUM}),\s*({NUM}),\s*'([^']*)'(?:,\s*step:\s*({NUM}))?\s*\)"
    return {k: {"min": num(a), "max": num(b), "label": lab, "step": num(s) if s else 1}
            for k, a, b, lab, s in re.findall(pat, block)}


def parse_devices(lsrc: str) -> dict:
    block = need(re.search(r"kDevices = \{(.*?)\n\};", lsrc, re.S), "kDevices").group(1)
    pat = r"'(\w+)':\s*DeviceSpec\(\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*(\d+)\s*\)"
    return {k: {"device": d, "route": r, "kind": kd, "age_min": int(a)}
            for k, d, r, kd, a in re.findall(pat, block)}


def parse_baselines(zsrc: str) -> dict:
    block = need(re.search(r"kBase = \{(.*?)\};", zsrc, re.S), "kBase").group(1)
    return {k: num(v) for k, v in re.findall(rf"'(\w+)':\s*({NUM})", block)}


def parse_meta(zsrc: str, esrc: str) -> dict:
    ints = lambda name: [int(x) for x in re.findall(r"\d+", need(  # noqa: E731
        re.search(rf"const List<int> {name} = \[([^\]]*)\];", esrc), name).group(1))]
    tiers = re.findall(r"'([^']*)'", need(
        re.search(r"const List<String> kTierNames = \[(.*?)\];", esrc, re.S), "kTierNames").group(1))
    m = need(re.search(
        rf"final dl = r < ({NUM}) \? (\d) : r < ({NUM}) \? (\d) : r < ({NUM}) \? (\d) : (\d);", esrc),
        "radiation dose-rate bands (lv() 'final dl = ...')")
    a, la, b, lb, c, lc, ld = m.groups()
    return {
        "plan_bed": need(re.search(r"kPlanBed = '([^']*)'", zsrc), "kPlanBed").group(1),
        "plan_up": need(re.search(r"kPlanUp = '([^']*)'", zsrc), "kPlanUp").group(1),
        "health_score": ints("kScore"), "health_cap": ints("kCap"), "tier_names": tiers,
        # [from_ratio, to_ratio, level] of (dose rate / environment's expected dose rate)
        "radiation_rate_bands": [[0, num(a), int(la)], [num(a), num(b), int(lb)],
                                 [num(b), num(c), int(lc)], [num(c), None, int(ld)]],
    }


def parse_reading_defs(asrc: str) -> tuple[dict, list]:
    """What the app REALLY posts per series key: app_state.dart _readingDef() -> (metric, field, unit)."""
    body = need(re.search(r"_readingDef\(String key\) \{(.*?)\n  \}\n", asrc, re.S), "_readingDef()").group(1)
    defs = {k: {"metric": a, "field": b, "unit": c} for k, a, b, c in
            re.findall(r"case '(\w+)':\s*return \('(\w+)', '(\w+)', '([^']*)'\);", body)}
    unsent = re.findall(r"case '(\w+)':\s*return null;", body)
    return defs, unsent


def extra_metrics(metrics: list, defs: dict, limits: dict) -> list:
    """Metrics the app posts that its own registry (kMetrics) does not list, e.g. 'dose_rate'."""
    known = {m["api_metric"] for m in metrics}
    out = []
    for series, d in defs.items():
        if d["metric"] in known:
            continue
        step = limits.get(series, {}).get("step", 1)
        decimals = len(str(step).split(".")[1]) if isinstance(step, float) else 0
        out.append({"id": d["metric"], "api_metric": d["metric"], "field": d["field"],
                    "name": d["metric"].replace("_", " ").capitalize(), "unit": d["unit"],
                    "series_key": series, "decimals": decimals, "extra": True})
    return out


def parse_fields(fsrc: str) -> list:
    block = fsrc[need(re.search(r"const List<FieldDef> kFields = \[", fsrc), "kFields").end():]
    starts = [m for m in re.finditer(
        r"FieldDef\(\s*id:\s*'(\w+)',\s*hz:\s*'(\w+)',\s*label:\s*'((?:[^'\\]|\\.)*)',\s*kind:\s*'(\w+)'", block)]
    out = []
    for i, m in enumerate(starts):
        seg = block[m.start(): starts[i + 1].start() if i + 1 < len(starts) else len(block)]
        out.append({"id": m.group(1), "hz": m.group(2), "label": m.group(3).replace("\\'", "'"),
                    "kind": m.group(4), "log": not re.search(r"\blog:\s*false", seg)})
    return out


def norm_unit(u: str) -> str:
    return re.sub(r"\s+", "", u).lower()


def build(lib: Path) -> dict:
    src = {rel: (lib / rel).read_text(encoding="utf-8") for rel in FILES}
    models, limits_src = src["contract/models.dart"], src["contract/limits.dart"]
    metrics = parse_metrics(models)
    limits = parse_limits(limits_src)
    defs, unsent = parse_reading_defs(src["data/app_state.dart"])
    metrics += extra_metrics(metrics, defs, limits)
    meta = parse_meta(src["contract/zones.dart"], src["engine/engine.dart"])
    meta["unsent_series"] = unsent          # series the app never posts (e.g. 'dia': sent with systolic)
    body = {
        "environments": parse_envs(models),
        "metrics": metrics,
        "reading_defs": defs,
        "fields": parse_fields(src["contract/fields.dart"]),
        "zones": parse_zones(src["contract/zones.dart"], models),
        "limits": limits,
        "baselines": parse_baselines(src["contract/zones.dart"]),
        "devices": parse_devices(limits_src),
        "meta": meta,
    }
    # version = hash of the extracted rules only, so unrelated Dart edits never make it 'stale'
    digest = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    data = {"source": {"files": FILES, "sha256": digest}, **body}
    problems = validate(data)
    if problems:
        sys.exit("extract_rules: sanity check failed:\n  - " + "\n  - ".join(problems))
    for series, d in defs.items():   # informational: unit spelling differences between registry and posts
        reg = next((m for m in metrics if m["api_metric"] == d["metric"] and not m.get("extra")), None)
        if reg and reg["unit"] != d["unit"] and norm_unit(reg["unit"]) == norm_unit(d["unit"]):
            print(f"note: unit spelled '{reg['unit']}' in kMetrics but posted as '{d['unit']}' ({d['metric']}); "
                  f"treated as the same")
    return data


def validate(d: dict) -> list[str]:
    p = []
    for name, n in [("environments", 4), ("zones", 16), ("limits", 15), ("devices", 15)]:
        if len(d[name]) != n:
            p.append(f"expected {n} {name}, found {len(d[name])}")
    if sum(1 for m in d["metrics"] if not m.get("extra")) != 15:
        p.append("expected 15 metrics in kMetrics")
    if len(d["fields"]) < 30:
        p.append(f"expected 30+ fields, found {len(d['fields'])}")
    if not d["reading_defs"]:
        p.append("no reading definitions found in app_state.dart _readingDef()")
    for key, z in d["zones"].items():
        b = z["bands"]
        if not b:
            p.append(f"zone '{key}' has no bands")
        for i in range(len(b) - 1):
            if b[i][1] != b[i + 1][0]:
                p.append(f"zone '{key}' bands are not contiguous at {b[i]} -> {b[i + 1]}")
        if any(x[0] >= x[1] for x in b):
            p.append(f"zone '{key}' has an empty or reversed band")
    return p


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("lib", type=Path, help="path to the Flutter app's lib/core directory (or lib/)")
    ap.add_argument("--check", action="store_true", help="only verify app/rules/rules_data.json is up to date")
    a = ap.parse_args()
    lib = a.lib / "core" if (a.lib / "core").is_dir() else a.lib
    data = build(lib)
    text = json.dumps(data, indent=1, ensure_ascii=False) + "\n"
    if a.check:
        ok = OUT.exists() and json.loads(OUT.read_text(encoding="utf-8")) == data
        print("rules_data.json is up to date" if ok else "rules_data.json is STALE: re-run without --check")
        sys.exit(0 if ok else 1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT}")
    print(f"  {len(data['environments'])} environments, {len(data['metrics'])} metrics, {len(data['zones'])} zone tables "
          f"({sum(len(z['bands']) for z in data['zones'].values())} bands), {len(data['limits'])} limits, "
          f"{len(data['baselines'])} baselines, {len(data['devices'])} devices, {len(data['fields'])} fields")
    extras = [m["api_metric"] for m in data["metrics"] if m.get("extra")]
    print(f"  posted by the app but missing from kMetrics (added): {extras}; never posted: {data['meta']['unsent_series']}")


if __name__ == "__main__":
    main()
