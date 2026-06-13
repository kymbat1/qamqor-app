import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, Request, status
from sqlalchemy import and_, select

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import DoctorProfile, EmailVerificationCode, User, UserRole
from app.services.email_delivery import EmailDeliveryError, send_verification_email


_request_log: dict[str, list[datetime]] = {}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _check_honeypot(value: str | None) -> None:
    if value:
        raise HTTPException(status_code=400, detail="registration rejected")


def _check_ip_rate_limit(request: Request) -> None:
    client_host = request.client.host if request.client else "unknown"
    now = _utcnow()
    window_start = now - timedelta(minutes=10)
    recent = [
        item for item in _request_log.get(client_host, []) if item >= window_start
    ]
    if len(recent) >= 20:
        raise HTTPException(status_code=429, detail="too many requests")
    recent.append(now)
    _request_log[client_host] = recent


def _generate_code() -> str:
    return f"{secrets.randbelow(900000) + 100000}"


def _hash_code(email: str, code: str, salt: str) -> str:
    settings = get_settings()
    payload = f"{_normalize_email(email)}:{code}:{salt}".encode()
    secret = settings.jwt_secret_key.encode()
    return hmac.new(secret, payload, hashlib.sha256).hexdigest()


def _is_expired(record: EmailVerificationCode) -> bool:
    expires_at = record.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at <= _utcnow()


def _is_resend_available(record: EmailVerificationCode) -> bool:
    resend_at = record.resend_available_at
    if resend_at.tzinfo is None:
        resend_at = resend_at.replace(tzinfo=timezone.utc)
    return resend_at <= _utcnow()


async def start_email_registration(
    *,
    db,
    request: Request,
    name: str,
    email: str,
    password: str,
    role: UserRole,
    website: str | None = None,
) -> tuple[EmailVerificationCode, str | None]:
    settings = get_settings()
    _check_honeypot(website)
    _check_ip_rate_limit(request)

    normalized_email = _normalize_email(email)
    existing_user = await db.scalar(select(User).where(User.email == normalized_email))
    if existing_user is not None:
        raise HTTPException(status_code=409, detail="user already exists")

    existing_code = await _get_latest_pending_code(db, normalized_email)
    now = _utcnow()
    if existing_code and not existing_code.is_used and not _is_expired(existing_code):
        if not _is_resend_available(existing_code):
            raise HTTPException(status_code=429, detail="resend is not available yet")
        if existing_code.send_count >= settings.verification_code_max_sends:
            raise HTTPException(status_code=429, detail="too many verification emails")

    code = _generate_code()
    salt = secrets.token_urlsafe(16)
    expires_at = now + timedelta(minutes=settings.verification_code_ttl_minutes)
    resend_available_at = now + timedelta(
        seconds=settings.verification_code_resend_seconds,
    )

    record = existing_code
    if record is None or record.is_used or _is_expired(record):
        record = EmailVerificationCode(
            email=normalized_email,
            name=name.strip(),
            password_hash=hash_password(password),
            role=role,
            code_hash=_hash_code(normalized_email, code, salt),
            salt=salt,
            expires_at=expires_at,
            resend_available_at=resend_available_at,
        )
        db.add(record)
    else:
        record.name = name.strip()
        record.password_hash = hash_password(password)
        record.role = role
        record.code_hash = _hash_code(normalized_email, code, salt)
        record.salt = salt
        record.attempts = 0
        record.send_count += 1
        record.expires_at = expires_at
        record.resend_available_at = resend_available_at

    debug_code = await _send_code_or_rollback(db, normalized_email, code)
    await db.commit()
    await db.refresh(record)
    return record, debug_code


async def resend_email_registration_code(
    *,
    db,
    request: Request,
    email: str,
    website: str | None = None,
) -> tuple[EmailVerificationCode, str | None]:
    settings = get_settings()
    _check_honeypot(website)
    _check_ip_rate_limit(request)

    normalized_email = _normalize_email(email)
    record = await _get_latest_pending_code(db, normalized_email)
    if record is None or record.is_used or _is_expired(record):
        raise HTTPException(status_code=404, detail="verification code not found")
    if not _is_resend_available(record):
        raise HTTPException(status_code=429, detail="resend is not available yet")
    if record.send_count >= settings.verification_code_max_sends:
        raise HTTPException(status_code=429, detail="too many verification emails")

    now = _utcnow()
    code = _generate_code()
    salt = secrets.token_urlsafe(16)
    record.code_hash = _hash_code(normalized_email, code, salt)
    record.salt = salt
    record.attempts = 0
    record.send_count += 1
    record.expires_at = now + timedelta(minutes=settings.verification_code_ttl_minutes)
    record.resend_available_at = now + timedelta(
        seconds=settings.verification_code_resend_seconds,
    )

    debug_code = await _send_code_or_rollback(db, normalized_email, code)
    await db.commit()
    await db.refresh(record)
    return record, debug_code


async def verify_email_registration(*, db, email: str, code: str) -> User:
    settings = get_settings()
    normalized_email = _normalize_email(email)
    record = await _get_latest_pending_code(db, normalized_email)
    if record is None or record.is_used:
        raise HTTPException(status_code=404, detail="verification code not found")
    if _is_expired(record):
        raise HTTPException(status_code=410, detail="verification code expired")
    if record.attempts >= settings.verification_code_max_attempts:
        raise HTTPException(status_code=429, detail="too many wrong attempts")

    incoming_hash = _hash_code(normalized_email, code, record.salt)
    if not hmac.compare_digest(incoming_hash, record.code_hash):
        record.attempts += 1
        await db.commit()
        raise HTTPException(status_code=400, detail="invalid verification code")

    existing_user = await db.scalar(select(User).where(User.email == normalized_email))
    if existing_user is not None:
        record.is_used = True
        await db.commit()
        raise HTTPException(status_code=409, detail="user already exists")

    user = User(
        name=record.name,
        email=normalized_email,
        role=record.role,
        password_hash=record.password_hash,
        email_verified=True,
    )
    db.add(user)
    await db.flush()
    if user.role == UserRole.doctor:
        db.add(
            DoctorProfile(
                user_id=user.id,
                name=user.name,
                specialty="",
                hospital="",
            ),
        )
    record.is_used = True
    await db.commit()
    await db.refresh(user)
    return user


async def _get_latest_pending_code(db, email: str) -> EmailVerificationCode | None:
    result = await db.execute(
        select(EmailVerificationCode)
        .where(
            and_(
                EmailVerificationCode.email == _normalize_email(email),
                EmailVerificationCode.is_used.is_(False),
            ),
        )
        .order_by(EmailVerificationCode.created_at.desc()),
    )
    return result.scalars().first()


async def _send_code_or_rollback(db, email: str, code: str) -> str | None:
    try:
        return await send_verification_email(email, code)
    except EmailDeliveryError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail=str(exc)) from exc
