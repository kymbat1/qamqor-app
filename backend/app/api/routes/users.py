from fastapi import APIRouter, Depends
from sqlalchemy import select

from app.deps import CurrentUser, DbSession, require_roles
from app.models import User, UserRole
from app.schemas import UserPublic, UserUpdate


router = APIRouter()


@router.get("/me", response_model=UserPublic)
async def get_me(user: CurrentUser) -> User:
    return user


@router.patch("/me", response_model=UserPublic)
async def update_me(payload: UserUpdate, db: DbSession, user: CurrentUser) -> User:
    data = payload.model_dump(exclude_unset=True)
    for field, value in data.items():
        if value is not None:
            setattr(user, field, value.strip() if isinstance(value, str) else value)
    await db.commit()
    await db.refresh(user)
    return user


@router.get("", response_model=list[UserPublic])
async def list_users(
    db: DbSession,
    _: User = Depends(require_roles(UserRole.admin)),
) -> list[User]:
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    return list(result.scalars().all())
