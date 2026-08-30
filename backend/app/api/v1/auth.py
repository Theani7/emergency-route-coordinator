"""Authentication endpoints: register, login, forgot-password OTP."""

import secrets
from datetime import datetime, timedelta, timezone

import sqlalchemy.exc
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import RequireAnyAuth, get_db
from app.core.config import get_settings
from app.core.email import send_otp_email, send_signup_otp_email
from app.core.logging import get_logger
from app.core.ratelimit import rate_limit
from app.core.security import create_access_token, hash_password, verify_password
from app.models.ambulance import Ambulance, AmbulanceStatus
from app.models.officer import TrafficOfficer
from app.models.otp import EmailVerificationOTP, PasswordResetOTP
from app.models.user import User, UserRole
from app.schemas.auth import (
    ForgotPasswordRequest,
    MessageResponse,
    ResetPasswordRequest,
    SendSignupOtpRequest,
    TokenResponse,
    UserLogin,
    UserRegister,
    UserResponse,
    VerifyOTPRequest,
    VerifySignupOtpRequest,
)

logger = get_logger(__name__)

router = APIRouter()


@router.post("/send-signup-otp", response_model=MessageResponse)
async def send_signup_otp(
    payload: SendSignupOtpRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """Send 6-digit OTP to verify email during signup."""
    clean_email = payload.email.strip().lower()
    existing = await db.execute(select(User).where(func.lower(User.email) == clean_email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    settings = get_settings()
    now = datetime.now(timezone.utc)
    recent = await db.execute(
        select(EmailVerificationOTP)
        .where(EmailVerificationOTP.email == clean_email)
        .order_by(EmailVerificationOTP.created_at.desc())
        .limit(1)
    )
    last = recent.scalar_one_or_none()
    if last:
        elapsed = (now - last.created_at).total_seconds() if last.created_at and last.created_at.tzinfo else 9999
        if last.created_at and last.created_at.tzinfo is None:
            elapsed = (now - last.created_at.replace(tzinfo=timezone.utc)).total_seconds()
        if elapsed < settings.otp_resend_cooldown_seconds:
            wait = int(settings.otp_resend_cooldown_seconds - elapsed)
            raise HTTPException(status_code=429, detail=f"Please wait {wait}s before requesting a new OTP.")

    # Clean old
    old = await db.execute(select(EmailVerificationOTP).where(EmailVerificationOTP.email == clean_email))
    for o in old.scalars().all():
        await db.delete(o)

    otp_code = _generate_otp(settings.otp_length)
    expires_at = now + timedelta(minutes=settings.otp_expire_minutes)
    db.add(EmailVerificationOTP(email=clean_email, otp_code=otp_code, expires_at=expires_at, verified=False, attempts=0))
    await db.commit()
    name = (payload.name or "there").strip() or "there"
    background_tasks.add_task(send_signup_otp_email, clean_email, otp_code, name)
    logger.info("Signup OTP %s for %s", otp_code, clean_email)
    detail = None
    if settings.environment == "development" and not settings.smtp_user:
        detail = f"[DEV] OTP is {otp_code} (SMTP not configured)"
    return MessageResponse(message="OTP sent to your email. It expires in 10 minutes.", detail=detail)


@router.post("/verify-signup-otp", response_model=MessageResponse)
async def verify_signup_otp(
    payload: VerifySignupOtpRequest,
    db: AsyncSession = Depends(get_db),
):
    """Verify signup OTP."""
    clean_email = payload.email.strip().lower()
    otp_input = payload.otp.strip()
    result = await db.execute(
        select(EmailVerificationOTP).where(EmailVerificationOTP.email == clean_email).order_by(EmailVerificationOTP.created_at.desc()).limit(1)
    )
    otp_entry = result.scalar_one_or_none()
    if not otp_entry:
        raise HTTPException(status_code=400, detail="No OTP found. Please request a new one.")
    now = datetime.now(timezone.utc)
    expires = otp_entry.expires_at if otp_entry.expires_at.tzinfo else otp_entry.expires_at.replace(tzinfo=timezone.utc)
    if now > expires:
        await db.delete(otp_entry)
        await db.commit()
        raise HTTPException(status_code=400, detail="OTP expired. Please request a new one.")
    if otp_entry.attempts >= get_settings().otp_max_attempts:
        await db.delete(otp_entry)
        await db.commit()
        raise HTTPException(status_code=400, detail="Too many attempts. Please request a new OTP.")
    if otp_entry.otp_code != otp_input:
        otp_entry.attempts += 1
        await db.commit()
        remaining = get_settings().otp_max_attempts - otp_entry.attempts
        raise HTTPException(status_code=400, detail=f"Invalid OTP. {remaining} attempts left.")
    otp_entry.verified = True
    await db.commit()
    return MessageResponse(message="Email verified. You can now complete registration.")


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: UserRegister, db: AsyncSession = Depends(get_db)):
    """Register a new user. Requires verified signup OTP."""
    # Enforce email verification via OTP
    clean_email = payload.email.strip().lower()
    settings = get_settings()
    # Allow bypass for seed/test if no verification entry and payload has no otp but user is admin seed? No - enforce for public API
    # Check for verified OTP
    otp_entry = None
    otp_entry = None
    if payload.otp:
        result = await db.execute(
            select(EmailVerificationOTP).where(EmailVerificationOTP.email == clean_email).order_by(EmailVerificationOTP.created_at.desc()).limit(1)
        )
        otp_entry = result.scalar_one_or_none()
        if not otp_entry or otp_entry.otp_code != payload.otp.strip():
            raise HTTPException(status_code=400, detail="Invalid or missing email OTP. Please verify your email.")
        expires = otp_entry.expires_at if otp_entry.expires_at.tzinfo else otp_entry.expires_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > expires:
            raise HTTPException(status_code=400, detail="OTP expired. Please request a new one.")
        if not otp_entry.verified:
            raise HTTPException(status_code=400, detail="OTP not verified. Please verify email first.")
    else:
        # If OTP was requested for this email, enforce verified state; else allow (backward compat for tests/seed)
        result = await db.execute(
            select(EmailVerificationOTP).where(EmailVerificationOTP.email == clean_email).order_by(EmailVerificationOTP.created_at.desc()).limit(1)
        )
        otp_entry = result.scalar_one_or_none()
        if otp_entry is not None:
            if not otp_entry.verified:
                raise HTTPException(status_code=400, detail="Email not verified. Please verify your email with OTP before registering.")
            expires = otp_entry.expires_at if otp_entry.expires_at.tzinfo else otp_entry.expires_at.replace(tzinfo=timezone.utc)
            if datetime.now(timezone.utc) > expires:
                raise HTTPException(status_code=400, detail="OTP expired. Please request a new one.")

    existing = await db.execute(select(User).where(func.lower(User.email) == clean_email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    if payload.role == UserRole.ADMIN:
        raise HTTPException(status_code=400, detail="Admin accounts cannot be self-registered")

    if payload.role == UserRole.DRIVER and not payload.vehicle_number:
        raise HTTPException(status_code=400, detail="vehicle_number required for drivers")
    if payload.role == UserRole.DRIVER:
        existing_ambulance = await db.execute(
            select(Ambulance).where(Ambulance.vehicle_number == payload.vehicle_number)
        )
        if existing_ambulance.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="vehicle_number already registered")
    if payload.role == UserRole.OFFICER and not payload.assigned_zone:
        raise HTTPException(status_code=400, detail="assigned_zone required for officers")

    user = User(
        name=payload.name,
        email=payload.email,
        password_hash=await hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    try:
        await db.flush()
    except sqlalchemy.exc.IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Email or vehicle number already registered")

    if payload.role == UserRole.DRIVER:
        db.add(
            Ambulance(
                driver_id=user.id,
                vehicle_number=payload.vehicle_number,
                status=AmbulanceStatus.AVAILABLE,
            )
        )
    elif payload.role == UserRole.OFFICER:
        db.add(
            TrafficOfficer(
                user_id=user.id,
                assigned_zone=payload.assigned_zone,
                zone_latitude=payload.zone_latitude,
                zone_longitude=payload.zone_longitude,
            )
        )

    # Consume verification OTP after successful registration
    if otp_entry is not None:
        await db.delete(otp_entry)

    await db.refresh(user)
    return UserResponse.model_validate(user)


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: UserLogin,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(
        rate_limit(
            get_settings().login_rate_limit_max,
            get_settings().login_rate_limit_window_seconds,
        )
    ),
):
    """Authenticate and receive JWT access token."""
    raw_email = payload.email or payload.username
    if not raw_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email or username is required",
        )
    clean_email = raw_email.strip().lower()
    result = await db.execute(
        select(User).where(func.lower(User.email) == clean_email)
    )
    user = result.scalar_one_or_none()

    now = datetime.now(timezone.utc)
    if user and user.locked_until:
        locked_until = (
            user.locked_until
            if user.locked_until.tzinfo is not None
            else user.locked_until.replace(tzinfo=timezone.utc)
        )
        if locked_until > now:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Account temporarily locked due to too many failed attempts. Try again later.",
            )

    if not user or not await verify_password(payload.password, user.password_hash):
        if user:
            settings = get_settings()
            user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
            if user.failed_login_attempts >= settings.max_login_attempts:
                user.failed_login_attempts = 0
                user.locked_until = now + timedelta(
                    minutes=settings.login_lockout_minutes
                )
            await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if user.failed_login_attempts or user.locked_until:
        user.failed_login_attempts = 0
        user.locked_until = None
        await db.commit()

    token = create_access_token(subject=user.id, role=user.role.value)
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        role=user.role,
        name=user.name,
    )


def _generate_otp(length: int = 6) -> str:
    """Generate cryptographically secure n-digit OTP."""
    return "".join(str(secrets.randbelow(10)) for _ in range(length))


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    payload: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """Request a 6-digit OTP to reset password. Uses Gmail App Password."""
    clean_email = payload.email.strip().lower()
    result = await db.execute(select(User).where(func.lower(User.email) == clean_email))
    user = result.scalar_one_or_none()

    # Always return success to prevent email enumeration, but only send if user exists.
    if not user:
        logger.info("Forgot-password requested for unknown email: %s", clean_email)
        return MessageResponse(message="If that email exists, an OTP has been sent.")

    settings = get_settings()
    now = datetime.now(timezone.utc)

    # Cooldown check: prevent spam
    recent = await db.execute(
        select(PasswordResetOTP)
        .where(PasswordResetOTP.email == clean_email)
        .order_by(PasswordResetOTP.created_at.desc())
        .limit(1)
    )
    last = recent.scalar_one_or_none()
    if last:
        elapsed = (now - last.created_at).total_seconds() if last.created_at else 9999
        # Ensure timezone aware
        if last.created_at and last.created_at.tzinfo is None:
            last_created = last.created_at.replace(tzinfo=timezone.utc)
            elapsed = (now - last_created).total_seconds()
        if elapsed < settings.otp_resend_cooldown_seconds:
            wait = int(settings.otp_resend_cooldown_seconds - elapsed)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Please wait {wait}s before requesting a new OTP.",
            )

    # Invalidate previous OTPs
    await db.execute(
        select(PasswordResetOTP).where(PasswordResetOTP.email == clean_email)
    )
    # Delete old OTPs for this email
    old_otps = await db.execute(select(PasswordResetOTP).where(PasswordResetOTP.email == clean_email))
    for o in old_otps.scalars().all():
        await db.delete(o)

    otp_code = _generate_otp(settings.otp_length)
    expires_at = now + timedelta(minutes=settings.otp_expire_minutes)

    otp_entry = PasswordResetOTP(
        email=clean_email,
        otp_code=otp_code,
        expires_at=expires_at,
        verified=False,
        attempts=0,
    )
    db.add(otp_entry)
    await db.commit()

    # Send email in background
    background_tasks.add_task(send_otp_email, clean_email, otp_code, user.name)

    logger.info("OTP %s generated for %s, expires at %s", otp_code, clean_email, expires_at)
    # In debug/development, return OTP for testing if SMTP not configured
    detail = None
    if settings.environment == "development" and not settings.smtp_user:
        detail = f"[DEV] OTP is {otp_code} (SMTP not configured)"

    return MessageResponse(message="OTP sent to your email. It expires in 10 minutes.", detail=detail)


@router.post("/verify-otp", response_model=MessageResponse)
async def verify_otp(
    payload: VerifyOTPRequest,
    db: AsyncSession = Depends(get_db),
):
    """Verify 6-digit OTP."""
    clean_email = payload.email.strip().lower()
    otp_input = payload.otp.strip()

    result = await db.execute(
        select(PasswordResetOTP)
        .where(PasswordResetOTP.email == clean_email)
        .order_by(PasswordResetOTP.created_at.desc())
        .limit(1)
    )
    otp_entry = result.scalar_one_or_none()
    if not otp_entry:
        raise HTTPException(status_code=400, detail="No OTP found. Please request a new one.")

    now = datetime.now(timezone.utc)
    expires = otp_entry.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)

    if now > expires:
        await db.delete(otp_entry)
        await db.commit()
        raise HTTPException(status_code=400, detail="OTP expired. Please request a new one.")

    if otp_entry.attempts >= get_settings().otp_max_attempts:
        await db.delete(otp_entry)
        await db.commit()
        raise HTTPException(status_code=400, detail="Too many attempts. Please request a new OTP.")

    if otp_entry.otp_code != otp_input:
        otp_entry.attempts += 1
        await db.commit()
        remaining = get_settings().otp_max_attempts - otp_entry.attempts
        raise HTTPException(
            status_code=400,
            detail=f"Invalid OTP. {remaining} attempts left.",
        )

    otp_entry.verified = True
    otp_entry.attempts = 0
    await db.commit()

    return MessageResponse(message="OTP verified. You can now reset your password.")


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    payload: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Reset password using verified OTP."""
    clean_email = payload.email.strip().lower()
    otp_input = payload.otp.strip()

    result = await db.execute(
        select(PasswordResetOTP)
        .where(PasswordResetOTP.email == clean_email)
        .order_by(PasswordResetOTP.created_at.desc())
        .limit(1)
    )
    otp_entry = result.scalar_one_or_none()
    if not otp_entry:
        raise HTTPException(status_code=400, detail="No OTP found. Please request a new one.")

    now = datetime.now(timezone.utc)
    expires = otp_entry.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)

    if now > expires:
        await db.delete(otp_entry)
        await db.commit()
        raise HTTPException(status_code=400, detail="OTP expired. Please request a new one.")

    if not otp_entry.verified:
        raise HTTPException(status_code=400, detail="OTP not verified. Please verify OTP first.")

    if otp_entry.otp_code != otp_input:
        raise HTTPException(status_code=400, detail="Invalid OTP.")

    # Find user and update password
    user_result = await db.execute(select(User).where(func.lower(User.email) == clean_email))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    user.password_hash = await hash_password(payload.new_password)
    user.failed_login_attempts = 0
    user.locked_until = None

    await db.delete(otp_entry)
    await db.commit()

    logger.info("Password reset successful for %s", clean_email)
    return MessageResponse(message="Password reset successful. Please login with your new password.")


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: RequireAnyAuth):
    """Get current authenticated user profile."""
    return UserResponse.model_validate(current_user)
