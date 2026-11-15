def test_profiles_has_everything_the_app_needs(client):
    r = client.get("/v1/profiles")
    assert r.status_code == 200
    d = r.json()
    assert set(d) >= {"version", "environments", "metrics", "fields", "zones", "limits", "baselines", "devices",
                      "plan", "score", "cap", "tierNames", "radiationRateBands"}
    assert len(d["environments"]) == 4 and len(d["zones"]) == 16 and len(d["fields"]) == 40
    assert len(d["version"]) == 64 and r.headers["etag"] == f'"{d["version"]}"'


def test_environment_uses_the_apps_own_field_names(client):
    env = {e["key"]: e for e in client.get("/v1/profiles").json()["environments"]}
    assert set(env["iss"]) == {"key", "n", "endA", "endB", "total", "day", "g", "dose", "limit", "delayMin", "phase"}
    assert (env["iss"]["dose"], env["iss"]["limit"], env["iss"]["delayMin"]) == (0.6, 50.0, 0.0)
    assert env["mars_transit"]["delayMin"] == 20.0 and env["mars_transit"]["limit"] == 250.0


def test_zones_limits_baselines_devices_plan(client):
    d = client.get("/v1/profiles").json()
    hr = d["zones"]["hr"]
    assert hr["bar"] == [35, 130] and hr["z"][0] == [30, 35, 4] and hr["z"][-1] == [130, 200, 4]
    assert d["zones"]["dia"]["bar"] is None
    assert d["limits"]["hr"] == {"min": 25, "max": 220, "label": "Heart rate", "step": 1}
    assert d["limits"]["temp"]["step"] == 0.1
    assert d["baselines"]["hr"] == 68 and d["baselines"]["temp"] == 36.6
    assert d["devices"]["rad"] == {"device": "Crew Active Dosimeter", "route": "Bluetooth to station computer",
                                   "kind": "direct", "ageMin": 55}
    assert d["plan"] == {"bed": "22:30", "up": "06:30"}
    assert d["cap"] == [100, 89, 79, 64, 49, 34] and d["score"][0] == 100
    assert d["radiationRateBands"] == [[0, 1.5, 0], [1.5, 3, 2], [3, 6, 3], [6, None, 4]]
    assert d["unsentSeries"] == ["dia"]


def test_metrics_carry_the_three_names(client):
    m = {x["id"]: x for x in client.get("/v1/profiles").json()["metrics"]}
    assert m["hr"] == {"id": "hr", "api": "heart_rate", "field": "heart_rate", "name": "Resting heart rate",
                       "unit": "bpm", "key": "hr", "decimals": 0}
    assert m["sleep"]["field"] == "sleep_hours_wakeups"
    assert m["dose_rate"]["unit"] == "mSv/day"


def test_every_zone_triple_is_well_formed(client):
    for key, z in client.get("/v1/profiles").json()["zones"].items():
        assert z["z"], key
        for lo, hi, lvl in z["z"]:
            assert lo < hi and lvl in range(6)


def test_etag_gives_304_when_nothing_changed(client):
    first = client.get("/v1/profiles")
    etag = first.headers["etag"]
    again = client.get("/v1/profiles", headers={"If-None-Match": etag})
    assert again.status_code == 304 and again.content == b""
    assert client.get("/v1/profiles", headers={"If-None-Match": '"old"'}).status_code == 200
