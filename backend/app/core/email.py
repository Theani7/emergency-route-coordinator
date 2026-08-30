"""Email service using Gmail App Password (SMTP)."""

import asyncio
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import get_settings
from app.core.logging import get_logger

logger = get_logger(__name__)


def _build_otp_html(otp: str, name: str = "there") -> str:
    """Branded HTML for OTP email with digit boxes."""
    digits_html = "".join(
        f'<span style="display:inline-block;width:44px;height:48px;line-height:48px;text-align:center;background:#FCEBEB;border:1.5px solid #E24B4A;border-radius:10px;font-size:22px;font-weight:700;color:#791F1F;margin:0 4px;letter-spacing:0;">{d}</span>'
        for d in otp
    )
    return f"""
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#F7F7F5;font-family:Inter,Arial,sans-serif;">
  <div style="max-width:480px;margin:0 auto;padding:24px;">
    <div style="background:#FFFFFF;border:1px solid #D3D1C7;border-radius:18px;overflow:hidden;box-shadow:0 6px 18px rgba(26,26,24,0.08);">
      <div style="background:#E24B4A;padding:20px 24px;text-align:center;">
        <div style="width:56px;height:56px;background:rgba(255,255,255,0.18);border-radius:14px;display:inline-flex;align-items:center;justify-content:center;color:#fff;font-size:28px;">🚑</div>
        <h1 style="margin:12px 0 0;color:#fff;font-size:20px;font-weight:700;letter-spacing:-0.3px;">Sajiloroute</h1>
        <p style="margin:4px 0 0;color:rgba(255,255,255,0.85);font-size:13px;">Emergency Response Network</p>
      </div>
      <div style="padding:28px 24px;">
        <h2 style="margin:0 0 8px;color:#1A1A18;font-size:18px;font-weight:600;">Password Reset OTP</h2>
        <p style="margin:0 0 4px;color:#5F5E5A;font-size:14px;">Hi {name},</p>
        <p style="margin:0 0 20px;color:#5F5E5A;font-size:14px;line-height:1.5;">Use the 6-digit code below to reset your password. It expires in <strong style="color:#1A1A18;">10 minutes</strong>.</p>
        <div style="text-align:center;padding:16px 0 20px;">
          {digits_html}
        </div>
        <div style="background:#F2F1ED;border-radius:10px;padding:14px 16px;margin-bottom:20px;">
          <p style="margin:0;color:#5F5E5A;font-size:12.5px;line-height:1.6;">⚠️ Don't share this code. If you didn't request a reset, you can safely ignore this email - your password stays unchanged.</p>
        </div>
        <p style="margin:0;color:#8A8880;font-size:12px;text-align:center;">Need help? Contact support at support@sajiloroute.com</p>
      </div>
      <div style="background:#F7F7F5;padding:14px 24px;text-align:center;border-top:1px solid #E4E2DA;">
        <p style="margin:0;color:#8A8880;font-size:11px;">© 2026 Sajiloroute • AI-Driven Ambulance Coordination</p>
      </div>
    </div>
    <p style="text-align:center;color:#B4B2A9;font-size:11px;margin:16px 0 0;">This is an automated email, please do not reply.</p>
  </div>
</body>
</html>
"""


def _send_sync(to_email: str, subject: str, html_body: str, text_body: str | None = None) -> None:
    settings = get_settings()
    if not settings.smtp_user or not settings.smtp_password:
        logger.warning("SMTP credentials not configured, skipping email to %s", to_email)
        # In development without SMTP, log OTP for testing
        logger.info("[DEV] Email to %s | Subject: %s | Body: %s", to_email, subject, text_body or html_body[:500])
        return

    from_addr = settings.smtp_from or settings.smtp_user
    from_name = settings.smtp_from_name

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{from_name} <{from_addr}>" if from_name else from_addr
    msg["To"] = to_email

    if text_body:
        msg.attach(MIMEText(text_body, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
            if settings.smtp_use_tls:
                server.starttls()
            server.login(settings.smtp_user, settings.smtp_password)
            server.sendmail(from_addr, [to_email], msg.as_string())
        logger.info("OTP email sent to %s", to_email)
    except Exception as exc:
        logger.exception("Failed to send email to %s: %s", to_email, exc)
        raise


def _build_signup_html(otp: str, name: str = "there") -> str:
    """Branded HTML for signup verification."""
    digits_html = "".join(
        f'<span style="display:inline-block;width:44px;height:48px;line-height:48px;text-align:center;background:#EAF1FC;border:1.5px solid #2E6FD8;border-radius:10px;font-size:22px;font-weight:700;color:#16396F;margin:0 4px;">{d}</span>'
        for d in otp
    )
    return f"""
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#F7F7F5;font-family:Inter,Arial,sans-serif;">
  <div style="max-width:480px;margin:0 auto;padding:24px;">
    <div style="background:#FFFFFF;border:1px solid #D3D1C7;border-radius:18px;overflow:hidden;box-shadow:0 6px 18px rgba(26,26,24,0.08);">
      <div style="background:#2E6FD8;padding:20px 24px;text-align:center;">
        <div style="width:56px;height:56px;background:rgba(255,255,255,0.18);border-radius:14px;display:inline-flex;align-items:center;justify-content:center;color:#fff;font-size:28px;">✓</div>
        <h1 style="margin:12px 0 0;color:#fff;font-size:20px;font-weight:700;">Sajiloroute</h1>
        <p style="margin:4px 0 0;color:rgba(255,255,255,0.85);font-size:13px;">Emergency Response Network</p>
      </div>
      <div style="padding:28px 24px;">
        <h2 style="margin:0 0 8px;color:#1A1A18;font-size:18px;font-weight:600;">Verify your email</h2>
        <p style="margin:0 0 4px;color:#5F5E5A;font-size:14px;">Hi {name},</p>
        <p style="margin:0 0 20px;color:#5F5E5A;font-size:14px;line-height:1.5;">Welcome! Use the code below to confirm your email and complete registration. Expires in <strong style="color:#1A1A18;">10 minutes</strong>.</p>
        <div style="text-align:center;padding:16px 0 20px;">{digits_html}</div>
        <div style="background:#F2F1ED;border-radius:10px;padding:14px 16px;margin-bottom:20px;">
          <p style="margin:0;color:#5F5E5A;font-size:12.5px;line-height:1.6;">If you didn't create an account, you can safely ignore this email.</p>
        </div>
        <p style="margin:0;color:#8A8880;font-size:12px;text-align:center;">Need help? support@sajiloroute.com</p>
      </div>
      <div style="background:#F7F7F5;padding:14px 24px;text-align:center;border-top:1px solid #E4E2DA;">
        <p style="margin:0;color:#8A8880;font-size:11px;">© 2026 Sajiloroute</p>
      </div>
    </div>
  </div>
</body>
</html>
"""


async def send_otp_email(to_email: str, otp: str, name: str = "there") -> None:
    """Send OTP email asynchronously (thread off event loop)."""
    subject = f"Your Sajiloroute OTP is {otp}"
    html_body = _build_otp_html(otp, name)
    text_body = f"Hi {name},\n\nYour Sajiloroute password reset OTP is: {otp}\nIt expires in 10 minutes.\n\nIf you didn't request this, ignore this email.\n"
    await asyncio.to_thread(_send_sync, to_email, subject, html_body, text_body)


async def send_signup_otp_email(to_email: str, otp: str, name: str = "there") -> None:
    """Send signup verification OTP."""
    subject = f"Verify your Sajiloroute email - {otp}"
    html_body = _build_signup_html(otp, name)
    text_body = f"Hi {name},\n\nYour Sajiloroute verification code is: {otp}\nIt expires in 10 minutes.\n"
    await asyncio.to_thread(_send_sync, to_email, subject, html_body, text_body)
