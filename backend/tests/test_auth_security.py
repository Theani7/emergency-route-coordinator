"""Security tests: login lockout, rate limiting and security headers."""

import time

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.core.ratelimit import reset
from app.main import app

pytestmark = pytest.mark.asyncio


@pytest.fixture(autouse=True)
def _reset_rate_limits():
    reset()
    yield
    reset()


async def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _register_driver(client: AsyncClient, suffix: str):
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "name": "Lockout Test",
            "email": f"lockout-{suffix}@example.com",
            "password": "Lockout@12345",
            "role": "driver",
            "vehicle_number": f"LKO-{suffix}",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_login_locks_account_after_failed_attempts():
    settings = get_settings()
    suffix = str(int(time.time() * 1000))
    async with await _client() as client:
        await _register_driver(client, suffix)

        login_payload = {
            "email": f"lockout-{suffix}@example.com",
            "password": "Lockout@12345",
        }

        for _ in range(settings.max_login_attempts):
            response = await client.post("/api/v1/auth/login", json=login_payload | {"password": "Wrong@12345"})
            assert response.status_code == 401

        response = await client.post("/api/v1/auth/login", json=login_payload)
        assert response.status_code == 429, response.text
        assert "locked" in response.json()["detail"].lower()


async def test_login_resets_counter_on_success():
    suffix = str(int(time.time() * 1000))
    async with await _client() as client:
        await _register_driver(client, suffix)
        login_payload = {
            "email": f"lockout-{suffix}@example.com",
            "password": "Lockout@12345",
        }

        response = await client.post(
            "/api/v1/auth/login", json=login_payload | {"password": "Wrong@12345"}
        )
        assert response.status_code == 401

        response = await client.post("/api/v1/auth/login", json=login_payload)
        assert response.status_code == 200, response.text
        assert "access_token" in response.json()


async def test_login_is_rate_limited_per_ip():
    settings = get_settings()
    payload = {"email": "nobody@example.com", "password": "Wrong@12345"}
    async with await _client() as client:
        for _ in range(settings.login_rate_limit_max):
            response = await client.post("/api/v1/auth/login", json=payload)
            assert response.status_code == 401

        response = await client.post("/api/v1/auth/login", json=payload)
        assert response.status_code == 429, response.text


async def test_security_headers_present():
    async with await _client() as client:
        response = await client.get("/health")
    assert response.headers["x-frame-options"].lower() == "deny"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["referrer-policy"].lower() == "no-referrer"
    assert "Content-Security-Policy" in response.headers


async def test_register_officer_without_assigned_zone():
    suffix = str(int(time.time() * 1000))
    async with await _client() as client:
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "name": "Live Location Officer",
                "email": f"officer-noz-{suffix}@example.com",
                "password": "Password@12345",
                "role": "officer",
            },
        )
        assert response.status_code == 201, response.text
        data = response.json()
        assert data["role"] == "officer"
        assert data["email"] == f"officer-noz-{suffix}@example.com"