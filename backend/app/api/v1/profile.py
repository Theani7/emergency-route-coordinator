"""Profile management endpoints for drivers and officers."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import RequireAnyAuth, RequireOfficer, get_db
from app.core.security import hash_password, verify_password
from app.models.officer import TrafficOfficer
from app.models.user import User
from app.schemas.profile import ChangePasswordRequest, ProfileResponse, ProfileUpdate

router = APIRouter()


def _build_profile(user: User) -> ProfileResponse:
    data = ProfileResponse(
        id=user.id,
        name=user.name,
        email=user.email,
        role=user.role.value,
        fcm_token=user.fcm_token,
    )
    if hasattr(user, "ambulance") and user.ambulance:
        data.vehicle_number = user.ambulance.vehicle_number
    if hasattr(user, "officer_profile") and user.officer_profile:
        data.assigned_zone = user.officer_profile.assigned_zone
        data.zone_latitude = user.officer_profile.zone_latitude
        data.zone_longitude = user.officer_profile.zone_longitude
        data.current_latitude = user.officer_profile.current_latitude
        data.current_longitude = user.officer_profile.current_longitude
        data.location_updated_at = user.officer_profile.location_updated_at
    return data


@router.get("/me", response_model=ProfileResponse)
async def get_profile(current_user: RequireAnyAuth, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User)
        .where(User.id == current_user.id)
        .options(
            selectinload(User.ambulance),
            selectinload(User.officer_profile),
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _build_profile(user)


@router.patch("/me", response_model=ProfileResponse)
async def update_profile(
    payload: ProfileUpdate,
    current_user: RequireAnyAuth,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User)
        .where(User.id == current_user.id)
        .options(
            selectinload(User.ambulance),
            selectinload(User.officer_profile),
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.name is not None:
        user.name = payload.name
    if payload.fcm_token is not None:
        user.fcm_token = payload.fcm_token

    await db.flush()
    await db.refresh(user)
    return _build_profile(user)


@router.post("/change-password")
async def change_password(
    payload: ChangePasswordRequest,
    current_user: RequireAnyAuth,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == current_user.id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not await verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    user.password_hash = await hash_password(payload.new_password)
    await db.flush()
    return {"message": "Password changed successfully"}


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float


@router.post("/location")
async def update_location(
    payload: LocationUpdate,
    current_user: RequireOfficer,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(TrafficOfficer).where(TrafficOfficer.user_id == current_user.id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Officer profile not found")
    profile.current_latitude = payload.latitude
    profile.current_longitude = payload.longitude
    profile.location_updated_at = datetime.now(timezone.utc)
    await db.flush()
    return {"message": "Location updated"}
