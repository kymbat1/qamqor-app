import asyncio
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT))

from app.db.init_db import database_summary, initialize_database, seed_core_data
from app.db.session import AsyncSessionLocal, engine


async def main() -> None:
    await initialize_database(engine)
    await seed_core_data(AsyncSessionLocal)
    summary = await database_summary(AsyncSessionLocal)
    print("PostgreSQL schema is ready.")
    for table, count in summary.items():
        print(f"{table}: {count}")


if __name__ == "__main__":
    asyncio.run(main())
