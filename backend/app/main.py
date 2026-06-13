from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import get_settings
from app.db.init_db import initialize_database
from app.db.session import engine


settings = get_settings()

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def create_tables_for_dev() -> None:
    if settings.environment == "development":
        await initialize_database(engine)


@app.get("/")
async def root() -> dict[str, str]:
    return {"status": "ok", "name": settings.app_name}


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "healthy"}


app.include_router(api_router, prefix=settings.api_prefix)
