from fastapi import APIRouter, Depends, HTTPException

from app.deps import DbSession, require_roles
from app.models import User, UserRole
from app.schemas import UserPublic


router = APIRouter()


@router.patch("/users/{user_id}/role", response_model=UserPublic)
async def update_user_role(
    user_id: str,
    role: UserRole,
    db: DbSession,
    _: User = Depends(require_roles(UserRole.admin)),
) -> User:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="user not found")
    user.role = role
    await db.commit()
    await db.refresh(user)
    return user


@router.patch("/users/{user_id}/active", response_model=UserPublic)
async def set_user_active(
    user_id: str,
    is_active: bool,
    db: DbSession,
    _: User = Depends(require_roles(UserRole.admin)),
) -> User:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="user not found")
    user.is_active = is_active
    await db.commit()
    await db.refresh(user)
    return user
