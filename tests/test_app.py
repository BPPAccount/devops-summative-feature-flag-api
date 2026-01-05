import os
import pytest
from fastapi.testclient import TestClient

from src.app import app, FLAGS

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_flags():
    FLAGS.clear()
    yield
    FLAGS.clear()


def test_health_ok():
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert "timeUtc" in data


def test_get_missing_flag_404():
    r = client.get("/flags/does-not-exist")
    assert r.status_code == 404


def test_put_requires_token():
    os.environ["ADMIN_TOKEN"] = "secret"
    r = client.put("/flags/demo", json={"value": True})
    assert r.status_code == 401


def test_put_with_token_and_get_roundtrip():
    os.environ["ADMIN_TOKEN"] = "secret"
    r = client.put(
        "/flags/demo",
        json={"value": {"enabled": True}},
        headers={"Authorization": "Bearer secret"},
    )
    assert r.status_code == 200

    r2 = client.get("/flags/demo")
    assert r2.status_code == 200
    assert r2.json()["value"] == {"enabled": True}
