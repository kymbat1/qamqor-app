from fastapi import APIRouter

from app.api.routes import (
    admin,
    ai,
    appointments,
    auth,
    chats,
    cycle,
    doctors,
    forum,
    reviews,
    users,
)


api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(doctors.router, prefix="/doctors", tags=["doctors"])
api_router.include_router(
    appointments.router,
    prefix="/appointments",
    tags=["appointments"],
)
api_router.include_router(cycle.router, prefix="/cycle", tags=["cycle"])
api_router.include_router(reviews.router, prefix="/reviews", tags=["reviews"])
api_router.include_router(chats.router, prefix="/chats", tags=["chats"])
api_router.include_router(forum.router, prefix="/forum", tags=["forum"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
