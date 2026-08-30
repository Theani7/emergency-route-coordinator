"""Security tests: login lockout, rate limiting and security headers."""

import time

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.ratelimit import reset
from app.database.session import async_session_maker
from app.main import app
from app.models.user import User, UserApprovalStatus

pytestmark = pytest.mark.asyncio


@pytest.fixture(autouse=True)
def _reset_rate_limits():
    reset()
    yield
    reset()


async def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _set_user_approval_status(email: str, status: UserApprovalStatus):
    async with async_session_maker() as db:
        res = await db.execute(select(User).where(func.lower(User.email) == email.lower()))
        user = res.scalar_one_or_none()
        if user:
            user.approval_status = status
            await db.commit()


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
        await _set_user_approval_status(
            f"lockout-{suffix}@example.com", UserApprovalStatus.APPROVED
        )
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
        assert data["approval_status"] == "pending"


async def test_pending_driver_registration_blocks_login_until_approved():
    suffix = str(int(time.time() * 1000))
    email = f"pending-driver-{suffix}@example.com"
    password = "Password@12345"
    async with await _client() as client:
        # 1. Register new driver via /api/v1/auth/register
        reg_response = await client.post(
            "/api/v1/auth/register",
            json={
                "name": "Pending Driver",
                "email": email,
                "password": password,
                "role": "driver",
                "vehicle_number": f"PND-{suffix}",
            },
        )
        # 2. Assert registration returns status 201 and response.json()["approval_status"] == "pending"
        assert reg_response.status_code == 201, reg_response.text
        data = reg_response.json()
        assert data["approval_status"] == "pending"

        # 3. Attempt login with the new driver credentials
        login_response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": email,
                "password": password,
            },
        )
        # 4. Assert login returns 403 Forbidden with detail "Your account is pending administrator approval."
        assert login_response.status_code == 403, login_response.text
        assert login_response.json()["detail"] == "Your account is pending administrator approval."

        # Verify login succeeds after admin approval
        await _set_user_approval_status(email, UserApprovalStatus.APPROVED)
        login_response_after = await client.post(
            "/api/v1/auth/login",
            json={
                "email": email,
                "password": password,
            },
        )
        assert login_response_after.status_code == 200, login_response_after.text
        assert "access_token" in login_response_after.json()


async def test_rejected_user_blocks_login():
    suffix = str(int(time.time() * 1000))
    email = f"rejected-user-{suffix}@example.com"
    password = "Password@12345"
    async with await _client() as client:
        reg_response = await client.post(
            "/api/v1/auth/register",
            json={
                "name": "Rejected Officer",
                "email": email,
                "password": password,
                "role": "officer",
            },
        )
        assert reg_response.status_code == 201, reg_response.text

        await _set_user_approval_status(email, UserApprovalStatus.REJECTED)

        login_response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": email,
                "password": password,
            },
        )
        assert login_response.status_code == 403, login_response.text
        assert (
            login_response.json()["detail"]
            == "Your registration request was rejected by an administrator."
        )