"""Database models, aligned with the Flutter app's data contract.

Conventions (same as the contract):
  * every time is UTC epoch MILLISECONDS stored as an integer (*_ms);
  * client-made string ids (readings, entries, alerts...) are the primary keys, so a
    resent item can never be saved twice;
  * the rule tables (rules.*) are loaded from the app's Dart files, never typed by hand.
"""
from typing import Optional

from sqlalchemy import (JSON, BigInteger, Boolean, CheckConstraint, Float, ForeignKey, Index, Integer, String,
                        UniqueConstraint)
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base

MS = BigInteger  # epoch milliseconds


# =============================================================== RULES ====
# Loaded from app/rules/rules_data.json (generated from the Dart sources).

class EnvProfile(Base):
    """ENV table: ISS / Moon / Mars transit / Mars surface."""
    __tablename__ = "env_profiles"
    key: Mapped[str] = mapped_column(String(30), primary_key=True)
    name: Mapped[str] = mapped_column(String(60))
    end_a: Mapped[str] = mapped_column(String(30))
    end_b: Mapped[str] = mapped_column(String(30))
    total_days: Mapped[int] = mapped_column(Integer)
    day: Mapped[int] = mapped_column(Integer)
    gravity: Mapped[str] = mapped_column(String(20))
    dose_rate_msv_day: Mapped[float] = mapped_column(Float)   # expected dose rate
    limit_msv: Mapped[float] = mapped_column(Float)           # mission dose limit
    delay_min: Mapped[float] = mapped_column(Float)           # one-way delay, minutes
    phase: Mapped[str] = mapped_column(String(40))


class MetricDef(Base):
    """One metric, three names: UI id <-> API metric <-> field id."""
    __tablename__ = "metric_defs"
    id: Mapped[str] = mapped_column(String(20), primary_key=True)        # UI id, e.g. 'hr'
    api_metric: Mapped[str] = mapped_column(String(40), unique=True)     # e.g. 'heart_rate'
    field: Mapped[str] = mapped_column(String(60))                       # e.g. 'heart_rate'
    name: Mapped[str] = mapped_column(String(60))
    unit: Mapped[str] = mapped_column(String(20))
    series_key: Mapped[str] = mapped_column(String(20))
    decimals: Mapped[int] = mapped_column(Integer, default=0)


class ZoneTable(Base):
    """One zone table per series key (hr, sys, dia, spo2, ...)."""
    __tablename__ = "zone_tables"
    series_key: Mapped[str] = mapped_column(String(20), primary_key=True)
    bar_min: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    bar_max: Mapped[Optional[float]] = mapped_column(Float, nullable=True)


class ZoneBand(Base):
    """A band [from, to) -> level 0..5 (0 normal ... 5 emergency)."""
    __tablename__ = "zone_bands"
    __table_args__ = (UniqueConstraint("series_key", "band_order"),
                      CheckConstraint("level BETWEEN 0 AND 5", name="ck_band_level"))
    id: Mapped[int] = mapped_column(primary_key=True)
    series_key: Mapped[str] = mapped_column(ForeignKey("zone_tables.series_key", ondelete="CASCADE"))
    band_order: Mapped[int] = mapped_column(Integer)
    from_value: Mapped[float] = mapped_column(Float)
    to_value: Mapped[float] = mapped_column(Float)
    level: Mapped[int] = mapped_column(Integer)


class InputLimit(Base):
    """LIM: smallest / largest value a person or device may submit."""
    __tablename__ = "input_limits"
    series_key: Mapped[str] = mapped_column(String(20), primary_key=True)
    min_value: Mapped[float] = mapped_column(Float)
    max_value: Mapped[float] = mapped_column(Float)
    label: Mapped[str] = mapped_column(String(60))
    step: Mapped[float] = mapped_column(Float, default=1)


class Baseline(Base):
    """BASE: personal baselines."""
    __tablename__ = "baselines"
    series_key: Mapped[str] = mapped_column(String(20), primary_key=True)
    value: Mapped[float] = mapped_column(Float)


class DeviceSpec(Base):
    """DEV: which device measures what, and how old its data usually is."""
    __tablename__ = "device_specs"
    series_key: Mapped[str] = mapped_column(String(20), primary_key=True)
    device: Mapped[str] = mapped_column(String(80))
    route: Mapped[str] = mapped_column(String(80))
    kind: Mapped[str] = mapped_column(String(20))   # direct | partial
    age_min: Mapped[int] = mapped_column(Integer)


class FieldDef(Base):
    """Check-in fields the app can save through POST /v1/entries (kFields)."""
    __tablename__ = "field_defs"
    id: Mapped[str] = mapped_column(String(60), primary_key=True)
    hz: Mapped[str] = mapped_column(String(10))       # hazard group: rad, iso, dist, grav, env
    label: Mapped[str] = mapped_column(String(100))
    kind: Mapped[str] = mapped_column(String(20))     # dev, mood, chips, journal, ...
    log: Mapped[bool] = mapped_column(Boolean, default=True)


class RuleMeta(Base):
    """Small settings: plan_bed, plan_up, health_score, health_cap, tier_names,
    radiation_rate_bands, source_sha256."""
    __tablename__ = "rule_meta"
    key: Mapped[str] = mapped_column(String(40), primary_key=True)
    value_json: Mapped[object] = mapped_column(JSON)


# ============================================================ IDENTITY ====

class Mission(Base):
    __tablename__ = "missions"
    id: Mapped[str] = mapped_column(String(50), primary_key=True)        # 'm_astrovitals_demo'
    name: Mapped[str] = mapped_column(String(100))
    env_key: Mapped[str] = mapped_column(ForeignKey("env_profiles.key"))
    total_days: Mapped[int] = mapped_column(Integer)


class Crew(Base):
    __tablename__ = "crew"
    id: Mapped[str] = mapped_column(String(50), primary_key=True)        # 'c1'
    name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(60), default="")
    mission_id: Mapped[str] = mapped_column(ForeignKey("missions.id"))


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(200), unique=True)
    password_hash: Mapped[str] = mapped_column(String(300))   # never the plain password
    name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(60), default="")
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    created_ms: Mapped[int] = mapped_column(MS)


class Session(Base):
    __tablename__ = "sessions"
    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)  # sha256 of the token
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    issued_ms: Mapped[int] = mapped_column(MS)
    expires_ms: Mapped[int] = mapped_column(MS)
    revoked_ms: Mapped[Optional[int]] = mapped_column(MS, nullable=True)


# ============================================================ MEASURES ====

class Reading(Base):
    """POST /v1/readings items. The client id is the key: a resend cannot duplicate."""
    __tablename__ = "readings"
    __table_args__ = (
        Index("ix_readings_crew_metric_time", "crew_id", "metric", "time_ms"),
        CheckConstraint("quality IN ('ok','stale','suspect')", name="ck_reading_quality"),
        CheckConstraint("source_kind IN ('device','manual')", name="ck_reading_source_kind"),
    )
    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    seq: Mapped[int] = mapped_column(Integer, default=0)
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    metric: Mapped[str] = mapped_column(ForeignKey("metric_defs.api_metric"))
    field: Mapped[str] = mapped_column(String(60))
    value: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(20))
    time_ms: Mapped[int] = mapped_column(MS)
    source_kind: Mapped[str] = mapped_column(String(10))
    source_device: Mapped[str] = mapped_column(String(80), default="")
    source_route: Mapped[str] = mapped_column(String(80), default="")
    source_type: Mapped[str] = mapped_column(String(20), default="direct")  # direct/partial/manual/none
    quality: Mapped[str] = mapped_column(String(10), default="ok")
    context_json: Mapped[dict] = mapped_column(JSON, default=dict)          # mission_day, location
    received_ms: Mapped[int] = mapped_column(MS)


class Entry(Base):
    """POST /v1/entries: manual check-in answers (mood, symptoms, journal, ...)."""
    __tablename__ = "entries"
    __table_args__ = (Index("ix_entries_crew_field_ts", "crew_id", "field", "ts_ms"),)
    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    seq: Mapped[int] = mapped_column(Integer, default=0)
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    field: Mapped[str] = mapped_column(String(60))
    payload_json: Mapped[dict] = mapped_column(JSON)
    ts_ms: Mapped[int] = mapped_column(MS)
    received_ms: Mapped[int] = mapped_column(MS)


# ============================================================== ALERTS ====

class Alert(Base):
    """GET /v1/alerts, GET /v1/status. Lifecycle: raised -> shown -> acknowledged / started /
    overridden / cleared."""
    __tablename__ = "alerts"
    __table_args__ = (
        Index("ix_alerts_crew_raised", "crew_id", "raised_ms"),
        CheckConstraint("lvl BETWEEN 0 AND 5", name="ck_alert_lvl"),
        CheckConstraint("tier BETWEEN 0 AND 4", name="ck_alert_tier"),
        CheckConstraint("state IN ('raised','shown','acknowledged','started','overridden','cleared')",
                        name="ck_alert_state"),
    )
    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    metric: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)  # null for pattern/field alerts
    field: Mapped[str] = mapped_column(String(60), default="")
    lvl: Mapped[int] = mapped_column(Integer)
    tier: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(200))
    obs: Mapped[str] = mapped_column(String(1000), default="")
    acts_json: Mapped[list] = mapped_column(JSON, default=list)
    contact: Mapped[str] = mapped_column(String(500), default="")
    state: Mapped[str] = mapped_column(String(15), default="raised")
    raised_ms: Mapped[int] = mapped_column(MS)
    updated_ms: Mapped[int] = mapped_column(MS)
    override_reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)


class AlertAction(Base):
    """Audit trail: every ack / start / override with its time. client_id = '<action>_<alertId>'
    from the app's queue, so a resent action is not saved twice."""
    __tablename__ = "alert_actions"
    __table_args__ = (CheckConstraint("action IN ('ack','start','override')", name="ck_action"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[str] = mapped_column(String(120), unique=True)
    alert_id: Mapped[str] = mapped_column(ForeignKey("alerts.id", ondelete="CASCADE"))
    action: Mapped[str] = mapped_column(String(10))
    reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    time_ms: Mapped[int] = mapped_column(MS)


# ========================================================== EMERGENCY ====

class Emergency(Base):
    __tablename__ = "emergencies"
    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    type: Mapped[str] = mapped_column(String(40))          # metric name or scenario, e.g. 'spo2'
    started_ms: Mapped[int] = mapped_column(MS)
    closed_ms: Mapped[Optional[int]] = mapped_column(MS, nullable=True)


class EmergencyEvent(Base):
    __tablename__ = "emergency_events"
    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[str] = mapped_column(String(120), unique=True)
    emergency_id: Mapped[str] = mapped_column(ForeignKey("emergencies.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(String(30))          # answer | closed | ...
    key: Mapped[str] = mapped_column(String(60))
    value_json: Mapped[object] = mapped_column(JSON)
    time_ms: Mapped[int] = mapped_column(MS)


# =============================================================== OTHER ====

class ContextConfirmation(Base):
    """POST /v1/context/confirm: the astronaut confirms or rejects a suggested context."""
    __tablename__ = "context_confirmations"
    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[str] = mapped_column(String(120), unique=True)
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    suggested: Mapped[str] = mapped_column(String(60))
    answer: Mapped[str] = mapped_column(String(20))
    signals_json: Mapped[dict] = mapped_column(JSON, default=dict)
    time_ms: Mapped[int] = mapped_column(MS)


class GroundReport(Base):
    """POST /v1/reports/ground: summary prepared for the flight surgeon."""
    __tablename__ = "ground_reports"
    id: Mapped[int] = mapped_column(primary_key=True)
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    created_ms: Mapped[int] = mapped_column(MS)
    payload_json: Mapped[dict] = mapped_column(JSON)


# ============================================================ AI TESTING ====
# Used to test the anomaly model against data whose correct answers are known.

class AnomalyLabel(Base):
    """The CORRECT ANSWER for simulated data: a window in which something really is (or really is
    not) wrong. expected=False marks harmless blips the model must NOT flag.
    metric = an api metric name, or '_combined_' for a multi-signal pattern."""
    __tablename__ = "anomaly_labels"
    __table_args__ = (
        CheckConstraint("end_ms > start_ms", name="ck_label_window"),
        Index("ix_labels_crew_metric_start", "crew_id", "metric", "start_ms"),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    dataset: Mapped[str] = mapped_column(String(40), default="demo")
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    metric: Mapped[str] = mapped_column(String(40))
    start_ms: Mapped[int] = mapped_column(MS)
    end_ms: Mapped[int] = mapped_column(MS)
    scenario: Mapped[str] = mapped_column(String(40))
    expected: Mapped[bool] = mapped_column(Boolean, default=True)
    note: Mapped[str] = mapped_column(String(300), default="")


class AnomalyResult(Base):
    """What the model said about one point in time."""
    __tablename__ = "anomaly_results"
    __table_args__ = (
        UniqueConstraint("model_version", "crew_id", "metric", "time_ms", name="uq_result_point"),
        CheckConstraint("score >= 0", name="ck_result_score"),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    crew_id: Mapped[str] = mapped_column(ForeignKey("crew.id"))
    metric: Mapped[str] = mapped_column(String(40))
    time_ms: Mapped[int] = mapped_column(MS)
    reading_id: Mapped[Optional[str]] = mapped_column(ForeignKey("readings.id"), nullable=True)
    score: Mapped[float] = mapped_column(Float)
    flagged: Mapped[bool] = mapped_column(Boolean)
    reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    model_version: Mapped[str] = mapped_column(String(40))
