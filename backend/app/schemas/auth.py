"""Authentication schemas."""

from typing import Any, Optional
from pydantic import BaseModel, EmailStr, Field, model_validator

from app.models.user import UserRole


class UserRegister(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    role: UserRole
    vehicle_number: str | None = Field(None, description="Required for drivers")
    assigned_zone: str | None = Field(None, description="Required for officers")
    zone_latitude: float | None = None
    zone_longitude: float | None = None
    otp: str | None = Field(None, min_length=6, max_length=6, description="6-digit email verification OTP")


class SendSignupOtpRequest(BaseModel):
    email: EmailStr
    name: str | None = Field(None, min_length=1, max_length=255)


class VerifySignupOtpRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)


class UserLogin(BaseModel):
    email: Optional[str] = Field(None, max_length=255)
    username: Optional[str] = Field(None, max_length=255)
    password: str = Field(..., min_length=1, max_length=128)

    @model_validator(mode="before")
    @classmethod
    def resolve_email_or_username(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if not data.get("email") and data.get("username"):
                data["email"] = data["username"]
        return data


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    role: UserRole
    name: str


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    role: UserRole
    vehicle_number: str | None = None
    assigned_zone: str | None = None

    model_config = {"from_attributes": True}


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyOTPRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit OTP")


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)
    new_password: str = Field(..., min_length=8, max_length=128)


class MessageResponse(BaseModel):
    message: str
    detail: str | None = None
