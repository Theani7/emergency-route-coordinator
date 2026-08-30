"""Tests for admin approval and user filtering workflows."""

import time
import pytest
from httpx import ASGITransport, AsyncClient

from app.core.ratelimit import reset
from app.core.security import create_access_token
from app.main import app
from app.models.user import UserRole

pytestmark = pytest.mark.asyncio


@pytest.fixture(autouse=True)
def _reset_rate_limits():
    reset()
    yield
    reset()


async def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_admin_approve_and_reject_user_flow():
    suffix = str(int(time.time() * 1000))
    driver_email = f"driver-flow-{suffix}@example.com"
    driver_password = "Password@12345"
    vehicle_no = f"AMB-{suffix}"

    admin_token = create_access_token(subject=1, role=UserRole.ADMIN.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    async with await _client() as client:
        # 1. Register a new driver (status becomes 'pending')
        reg_resp = await client.post(
            "/api/v1/auth/register",
            json={
                "name": "Pending Driver",
                "email": driver_email,
                "password": driver_password,
                "role": "driver",
                "vehicle_number": vehicle_no,
            },
        )
        assert reg_resp.status_code == 201, reg_resp.text
        driver_data = reg_resp.json()
        driver_id = driver_data["id"]
        assert driver_data["approval_status"] == "pending"

        # 2. As admin, call GET /api/v1/users/?approval_status=pending and verify user is in list
        list_resp = await client.get(
            "/api/v1/users/?approval_status=pending",
            headers=admin_headers,
        )
        assert list_resp.status_code == 200, list_resp.text
        pending_users = list_resp.json()
        assert any(u["id"] == driver_id for u in pending_users)
        assert all(u["approval_status"] == "pending" for u in pending_users)

        # 3. As admin, call POST /api/v1/users/{driver_id}/approve. Verify status 200, approval_status == "approved"
        approve_resp = await client.post(
            f"/api/v1/users/{driver_id}/approve",
            headers=admin_headers,
        )
        assert approve_resp.status_code == 200, approve_resp.text
        approved_data = approve_resp.json()
        assert approved_data["approval_status"] == "approved"
        assert approved_data["id"] == driver_id

        # 4. Login as newly approved driver. Verify login succeeds with 200 and returns valid token
        login_resp = await client.post(
            "/api/v1/auth/login",
            json={
                "email": driver_email,
                "password": driver_password,
            },
        )
        assert login_resp.status_code == 200, login_resp.text
        token_data = login_resp.json()
        assert "access_token" in token_data
        assert token_data["user_id"] == driver_id

        # 5. As admin, call POST /api/v1/users/{driver_id}/reject. Verify status 200, approval_status == "rejected"
        reject_resp = await client.post(
            f"/api/v1/users/{driver_id}/reject",
            headers=admin_headers,
        )
        assert reject_resp.status_code == 200, reject_resp.text
        rejected_data = reject_resp.json()
        assert rejected_data["approval_status"] == "rejected"
        assert rejected_data["id"] == driver_id

        # 6. Attempt to login as the rejected driver. Verify login fails with 403 Forbidden
        rejected_login_resp = await client.post(
            "/api/v1/auth/login",
            json={
                "email": driver_email,
                "password": driver_password,
            },
        )
        assert rejected_login_resp.status_code == 403, rejected_login_resp.text
        assert "rejected" in rejected_login_resp.json()["detail"].lower()


async def test_non_admin_cannot_approve_users():
    suffix = str(int(time.time() * 1000))
    driver_token = create_access_token(subject=2, role=UserRole.DRIVER.value)
    officer_token = create_access_token(subject=3, role=UserRole.OFFICER.value)

    driver_headers = {"Authorization": f"Bearer {driver_token}"}
    officer_headers = {"Authorization": f"Bearer {officer_token}"}

    async with await _client() as client:
        # Register a pending user
        reg_resp = await client.post(
            "/api/v1/auth/register",
            json={
                "name": "Target User",
                "email": f"target-{suffix}@example.com",
                "password": "Password@12345",
                "role": "officer",
            },
        )
        assert reg_resp.status_code == 201, reg_resp.text
        user_id = reg_resp.json()["id"]

        # Driver attempts to approve
        resp_driver_approve = await client.post(
            f"/api/v1/users/{user_id}/approve",
            headers=driver_headers,
        )
        assert resp_driver_approve.status_code == 403

        # Officer attempts to approve
        resp_officer_approve = await client.post(
            f"/api/v1/users/{user_id}/approve",
            headers=officer_headers,
        )
        assert resp_officer_approve.status_code == 403

        # Driver attempts to reject
        resp_driver_reject = await client.post(
            f"/api/v1/users/{user_id}/reject",
            headers=driver_headers,
        )
        assert resp_driver_reject.status_code == 403

        # Officer attempts to reject
        resp_officer_reject = await client.post(
            f"/api/v1/users/{user_id}/reject",
            headers=officer_headers,
        )
        assert resp_officer_reject.status_code == 403

        # Unauthenticated attempts
        resp_unauth_approve = await client.post(f"/api/v1/users/{user_id}/approve")
        assert resp_unauth_approve.status_code == 401

        resp_unauth_reject = await client.post(f"/api/v1/users/{user_id}/reject")
        assert resp_unauth_reject.status_code == 401


async def test_approve_reject_nonexistent_user():
    admin_token = create_access_token(subject=1, role=UserRole.ADMIN.value)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    async with await _client() as client:
        resp_approve = await client.post(
            "/api/v1/users/999999/approve",
            headers=admin_headers,
        )
        assert resp_approve.status_code == 404
        assert resp_approve.json()["detail"] == "User not found"

        resp_reject = await client.post(
            "/api/v1/users/999999/reject",
            headers=admin_headers,
        )
        assert resp_reject.status_code == 404
        assert resp_reject.json()["detail"] == "User not found"
