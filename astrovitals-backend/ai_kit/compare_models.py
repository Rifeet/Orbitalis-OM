#!/usr/bin/env python3
"""Compare anomaly detectors on the simulated crew, with ONE fair protocol.

    python compare_models.py <folder with readings.csv and truth.json> [--json out.json]
    needs: numpy pandas scikit-learn scipy

Protocol (no peeking at the answers)
  * Learning data  = each astronaut's first 20 days (days 20..39 before the end): all normal.
  * Personal baseline = median and robust spread (MAD) of those days, with the spread shrunk toward the crew-wide
    spread (only 20 days per person). Every reading becomes a personal z-score.
  * Thresholds are fixed in advance (3.5 sigma, chi-square 99.5 %, scikit-learn defaults, or the 99th percentile
    of leave-one-out scores on the learning days). Nothing is tuned on the test days.
  * SLOW layer: one 15-metric vector per astronaut per day (cumulative_dose excluded). Test days are the last 20.
    Raw flag, and "persistent" flag = flagged on 2 of the last 3 days.
  * ACUTE layer: c4 (4 vitals every 5 min) and c3 (dose rate hourly), persistent = 2 readings in a row.
"""
import argparse
import json
import warnings

import numpy as np
import pandas as pd
from scipy.stats import chi2
from sklearn.covariance import LedoitWolf
from sklearn.ensemble import IsolationForest
from sklearn.neighbors import LocalOutlierFactor, NearestNeighbors

warnings.filterwarnings("ignore")
DAY, MIN, HOUR = 86_400_000, 60_000, 3_600_000
FEATS = ["heart_rate", "blood_pressure", "spo2", "blood_glucose", "body_temperature", "sleep_hours", "mood_daily",
         "exercise_minutes", "respiratory_rate", "body_mass", "co2_ppm", "cabin_humidity", "cabin_temperature",
         "cabin_noise", "dose_rate"]
ACUTE4 = ["heart_rate", "blood_pressure", "spo2", "respiratory_rate"]
LEARN_FROM_J = 20
BLIP_DAYS = [18, 14, 10, 7, 4, 2]          # c1's harmless blips that fall in the test region


# ------------------------------------------------------------------ personal baselines
def personal_params(train: pd.DataFrame):
    """train: rows (crew, j) x metrics. -> median and spread per crew and metric."""
    med = train.groupby(level=0).median()
    mad = train.groupby(level=0).apply(lambda g: (g - g.median()).abs().median()) * 1.4826
    std = train.groupby(level=0).std()
    s = mad.where(mad > 0, std)                                   # integer metrics can have MAD = 0
    pool = s.median()
    n, m = len(train) / train.index.get_level_values(0).nunique(), 10
    sd = np.sqrt((n * s ** 2 + m * pool ** 2) / (n + m)).clip(lower=1e-6)
    return med, sd


def to_z(frame: pd.DataFrame, crew_of, med, sd, cols):
    crews = [crew_of(i) for i in frame.index]
    return (frame[cols].values - med.loc[crews, cols].values) / sd.loc[crews, cols].values


# ------------------------------------------------------------------ detectors: each returns raw flags for rows of X
def make_detectors(Xtr: np.ndarray, with_cov: bool = True, seed: int = 0):
    d = Xtr.shape[1]
    out = {}
    out["z_max (>3.5)"] = lambda X: np.abs(X).max(axis=1) > 3.5
    out["sum_z2 (chi2 99.5%)"] = lambda X: (X ** 2).sum(axis=1) > chi2.ppf(0.995, d)
    if with_cov:
        lw = LedoitWolf().fit(Xtr)
        prec, mu = lw.precision_, lw.location_
        out["mahalanobis (chi2 99.5%)"] = lambda X: np.einsum("ij,jk,ik->i", X - mu, prec, X - mu) > chi2.ppf(0.995, d)
    iso = IsolationForest(n_estimators=300, random_state=seed).fit(Xtr)
    out["isolation_forest"] = lambda X: iso.decision_function(X) < 0
    lof = LocalOutlierFactor(n_neighbors=10, novelty=True).fit(Xtr)
    out["lof"] = lambda X: lof.predict(X) == -1
    k = 5
    nn = NearestNeighbors(n_neighbors=k).fit(Xtr)
    loo = NearestNeighbors(n_neighbors=k + 1).fit(Xtr).kneighbors(Xtr)[0][:, 1:].mean(axis=1)
    thr = np.percentile(loo, 99)
    out["knn_distance"] = lambda X: nn.kneighbors(X)[0].mean(axis=1) > thr
    return out


def persist(flags: dict, k: int, window: int) -> dict:
    """flags: {order_key: bool} in chronological order -> flagged on k of the last `window` steps."""
    hist, out = [], {}
    for key in sorted(flags):
        hist.append(flags[key])
        out[key] = sum(hist[-window:]) >= k
    return out


# ------------------------------------------------------------------ slow layer
def slow_layer(daily: pd.DataFrame, med, sd, seed: int):
    train_mask = daily.index.get_level_values(1) >= LEARN_FROM_J
    Z = pd.DataFrame(to_z(daily, lambda i: i[0], med, sd, FEATS), index=daily.index, columns=FEATS)
    dets = make_detectors(Z[train_mask].values, True, seed)
    # one non-personal comparison: isolation forest on RAW values, all astronauts mixed
    raw_iso = IsolationForest(n_estimators=300, random_state=seed).fit(daily[train_mask][FEATS].values)
    dets["isolation_forest on RAW (no personal baseline)"] = lambda X, m=raw_iso: m.decision_function(X) < 0
    def mewma(lam: float = 0.3):
        """Multivariate EWMA of the personal z-vectors: small shifts that repeat add up over days."""
        flags = pd.Series(False, index=daily.index)
        for crew in daily.index.get_level_values(0).unique():
            js = sorted(Z.loc[crew].index, reverse=True)                  # oldest first
            e = np.zeros(len(FEATS))
            for t, j in enumerate(js, start=1):
                e = lam * Z.loc[(crew, j)].values + (1 - lam) * e
                var = lam / (2 - lam) * (1 - (1 - lam) ** (2 * t))
                flags[(crew, j)] = (e ** 2).sum() / var > chi2.ppf(0.995, len(FEATS))
        return flags
    flag_by_name = {"mewma (lambda 0.3, chi2 99.5%)": mewma()}
    rows = {}
    for name in list(dets) + list(flag_by_name):
        if name in flag_by_name:
            flag = flag_by_name[name]
        else:
            X = daily[FEATS].values if "RAW" in name else Z.values
            flag = pd.Series(dets[name](X), index=daily.index)
        for tag, k, w in (("raw", 1, 1), ("persistent", 2, 3)):
            F = {}
            for crew in daily.index.get_level_values(0).unique():
                series = {-j: bool(flag[(crew, j)]) for j in flag[crew].index}      # chronological = -j ascending
                P = persist(series, k, w)
                F.update({(crew, -key): v for key, v in P.items()})
            c2 = [j for j in range(19, -1, -1) if F[("c2", j)]]
            normal = [(c, j) for c in ("c1", "c3", "c4") for j in range(1, 20)]
            rows[(name, tag)] = {
                "c2 first alert (days before end)": c2[0] if c2 else None,
                "c2 flagged days of last 7": sum(F[("c2", j)] for j in range(7)),
                "false-alarm days (of 57 normal)": sum(F[d] for d in normal),
                "c1 blip days flagged (of 6)": sum(F[("c1", j)] for j in BLIP_DAYS),
                "c3 storm day flagged": bool(F[("c3", 0)]), "c4 emergency day flagged": bool(F[("c4", 0)]),
            }
    return pd.DataFrame(rows).T


# ------------------------------------------------------------------ acute layer
def acute_layer(df, daily, med, sd, end, seed):
    out = {}
    for crew, cols, t0, label in (("c4", ACUTE4, end - 120 * MIN, "c4 breathing emergency (5-min)"),
                                  ("c3", ["dose_rate"], end - 12 * HOUR, "c3 solar storm (hourly)")):
        tr = daily[daily.index.get_level_values(1) >= LEARN_FROM_J]
        Ztr = to_z(tr, lambda i: i[0], med, sd, cols)
        st = df[(df.crew_id == crew) & df.metric.isin(cols) & (df.time_ms >= t0)]
        piv = st.pivot_table(index="time_ms", columns="metric", values="value")[cols].sort_index()
        Zs = to_z(piv, lambda i: crew, med, sd, cols)
        dets = make_detectors(Ztr, with_cov=len(cols) > 1, seed=seed)
        res = {}
        for name, f in dets.items():
            raw = dict(zip(piv.index, f(Zs)))
            P = persist(raw, 2, 2)
            hits = [t for t in sorted(P) if P[t]]
            quiet = t0 + (65 * MIN if crew == "c4" else 3 * HOUR)       # before this the stream is still normal
            res[name] = {"first alert (min before end)": round((end - hits[0]) / MIN) if hits else None,
                         "false alarms in the normal part": sum(P[t] for t in P if t < quiet)}
        out[label] = pd.DataFrame(res).T
    return out


def run(folder: str, seed: int = 0):
    df = pd.read_csv(f"{folder}/readings.csv")
    truth = json.load(open(f"{folder}/truth.json"))
    end = truth["meta"]["end_ms"]
    df["j"] = (end - df.time_ms) / DAY
    d = df[(df.j - df.j.round()).abs() < 1e-9].copy()
    d["j"] = d.j.round().astype(int)
    daily = d.pivot_table(index=["crew_id", "j"], columns="metric", values="value")[FEATS]
    assert not daily.isna().any().any(), "daily table has gaps"
    med, sd = personal_params(daily[daily.index.get_level_values(1) >= LEARN_FROM_J])
    return slow_layer(daily, med, sd, seed), acute_layer(df, daily, med, sd, end, seed), truth


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--seed", type=int, default=0, help="seed of the isolation forest")
    ap.add_argument("--json")
    a = ap.parse_args()
    slow, acute, truth = run(a.folder, a.seed)
    pd.set_option("display.width", 200, "display.max_colwidth", 60)
    print("=== SLOW LAYER: one vector per astronaut per day (c2 drifts; the rules never alerted) ===")
    print(slow.to_string())
    for label, t in acute.items():
        print(f"\n=== ACUTE LAYER: {label} ===")
        print(t.to_string())
    f, end = truth["crew"], truth["meta"]["end_ms"]
    mins = lambda cid, k: round((end - f[cid]["rules_first_reached_level_ms"][k]) / MIN)   # noqa: E731
    print(f"\nWhen the app's RULES reacted (minutes before the end): c4 level1 {mins('c4','ge1')}, level2 {mins('c4','ge2')}, "
          f"level3 {mins('c4','ge3')}, level5 {mins('c4','ge5')};  c3 level2 {mins('c3','ge2')};  c2 never above level 1.")
    if a.json:
        json.dump({"slow": slow.reset_index(names=["detector", "tag"]).to_dict("records"),
                   "acute": {k: v.reset_index(names="detector").to_dict("records") for k, v in acute.items()}},
                  open(a.json, "w"), default=lambda o: o.item() if hasattr(o, "item") else str(o))
