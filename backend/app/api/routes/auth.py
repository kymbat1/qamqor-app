import secrets

from fastapi import APIRouter, HTTPException, Request, status
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError

from app.core.security import create_access_token, hash_password, verify_password
from app.deps import CurrentUser, DbSession
from app.models import DoctorProfile, User, UserRole
from app.schemas import (
    LoginRequest,
    PasswordlessLoginRequest,
    RegisterRequest,
    RegisterResendRequest,
    RegisterStartRequest,
    RegisterStartResponse,
    RegisterVerifyRequest,
    TokenResponse,
    UserPublic,
)
from app.services.email_verification import (
    resend_email_registration_code,
    start_email_registration,
    verify_email_registration,
)


router = APIRouter()


@router.post("/register/start", response_model=RegisterStartResponse, status_code=202)
async def start_register(
    payload: RegisterStartRequest,
    request: Request,
    db: DbSession,
) -> RegisterStartResponse:
    record, debug_code = await start_email_registration(
        db=db,
        request=request,
        name=payload.name,
        email=str(payload.email),
        password=payload.password,
        role=payload.role,
        website=payload.website,
    )
    return RegisterStartResponse(
        email=record.email,
        expires_at=record.expires_at,
        resend_available_at=record.resend_available_at,
        message="verification code sent",
        debug_code=debug_code,
    )


@router.post("/register/resend", response_model=RegisterStartResponse)
async def resend_register_code(
    payload: RegisterResendRequest,
    request: Request,
    db: DbSession,
) -> RegisterStartResponse:
    record, debug_code = await resend_email_registration_code(
        db=db,
        request=request,
        email=str(payload.email),
        website=payload.website,
    )
    return RegisterStartResponse(
        email=record.email,
        expires_at=record.expires_at,
        resend_available_at=record.resend_available_at,
        message="verification code sent",
        debug_code=debug_code,
    )


@router.post("/register/verify", response_model=TokenResponse, status_code=201)
async def verify_register(
    payload: RegisterVerifyRequest,
    db: DbSession,
) -> TokenResponse:
    user = await verify_email_registration(
        db=db,
        email=str(payload.email),
        code=payload.code,
    )
    return TokenResponse(
        access_token=create_access_token(user.id, {"role": user.role.value}),
    )


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(payload: RegisterRequest, db: DbSession) -> TokenResponse:
    if payload.email is None and payload.phone is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="email or phone is required",
        )

    filters = []
    if payload.email:
        filters.append(User.email == payload.email.lower())
    if payload.phone:
        filters.append(User.phone == payload.phone)

    existing = await db.execute(select(User).where(or_(*filters)))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="user already exists")

    user = User(
        name=payload.name.strip(),
        email=payload.email.lower() if payload.email else None,
        phone=payload.phone,
        role=payload.role,
        password_hash=hash_password(payload.password),
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

    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(status_code=409, detail="user already exists") from exc

    return TokenResponse(
        access_token=create_access_token(user.id, {"role": user.role.value}),
    )


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: DbSession) -> TokenResponse:
    result = await db.execute(
        select(User).where(User.email == payload.email.lower()),
    )
    user = result.scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid email or password",
        )

    if not user.is_active:
        raise HTTPException(status_code=403, detail="user is disabled")

    return TokenResponse(
        access_token=create_access_token(user.id, {"role": user.role.value}),
    )


@router.post("/passwordless-login", response_model=TokenResponse)
async def passwordless_login(
    payload: PasswordlessLoginRequest,
    db: DbSession,
) -> TokenResponse:
    if payload.email is None and payload.phone is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="email or phone is required",
        )

    filters = []
    if payload.email:
        filters.append(User.email == payload.email.lower())
    if payload.phone:
        filters.append(User.phone == payload.phone)

    result = await db.execute(select(User).where(or_(*filters)))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            name="Новый пользователь",
            email=payload.email.lower() if payload.email else None,
            phone=payload.phone,
            role=payload.role,
            password_hash=hash_password(secrets.token_urlsafe(24)[:32]),
        )
        db.add(user)
        await db.flush()
    elif payload.role == UserRole.doctor and user.role != UserRole.admin:
        user.role = UserRole.doctor

    if user.role == UserRole.doctor:
        existing_profile = await db.execute(
            select(DoctorProfile).where(DoctorProfile.user_id == user.id),
        )
        if existing_profile.scalar_one_or_none() is None:
            db.add(
                DoctorProfile(
                    user_id=user.id,
                    name=user.name,
                    specialty="",
                    hospital="",
                ),
            )

    await db.commit()
    return TokenResponse(
        access_token=create_access_token(user.id, {"role": user.role.value}),
    )


@router.get("/me", response_model=UserPublic)
async def me(user: CurrentUser) -> User:
    return user
