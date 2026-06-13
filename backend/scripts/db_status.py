import asyncio
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT))

from sqlalchemy import func, select

from app.db.init_db import database_summary
from app.db.session import AsyncSessionLocal
from app.models import User


async def main() -> None:
    summary = await database_summary(AsyncSessionLocal)
    async with AsyncSessionLocal() as session:
        role_rows = await session.execute(
            select(User.role, func.count(User.id)).group_by(User.role).order_by(User.role),
        )

    print("Tables:")
    for table, count in summary.items():
        print(f"  {table}: {count}")

    print("Roles:")
    for role, count in role_rows.all():
        print(f"  {role.value}: {count}")


if __name__ == "__main__":
    asyncio.run(main())
