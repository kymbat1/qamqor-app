# Qamqor Python Backend

FastAPI + PostgreSQL backend for the Qamqor Flutter app.

## Stack

- Python 3.12
- FastAPI
- PostgreSQL
- SQLAlchemy async
- JWT auth

## Local Setup

1. Create a database in pgAdmin:

```sql
CREATE DATABASE qamqor;
```

2. Create and activate a virtual environment:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

3. Install dependencies:

```powershell
pip install -r requirements.txt
```

4. Copy `.env.example` to `.env` and set your PostgreSQL password:

```env
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_DB=qamqor
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_postgres_password
JWT_SECRET_KEY=change_me_to_a_long_random_secret
```

5. Initialize tables, roles and seed data:

```powershell
python scripts/init_db.py
```

6. Run the API:

```powershell
uvicorn app.main:app --reload
```

Open:

- API: http://127.0.0.1:8000
- Swagger docs: http://127.0.0.1:8000/docs

## Roles

- `admin` - manages users, doctors and appointments.
- `doctor` - edits own doctor profile, sees appointments and chats.
- `client` - tracks cycle, books appointments, reviews doctors and chats.

## Demo Accounts

After `python scripts/init_db.py`:

- Admin: `admin@qamqor.kz` / `admin12345`
- Doctors: `asel.satova@qamqor.kz`, `lyazzat.kuanysheva@qamqor.kz`, `amina.omarova@qamqor.kz`, `dana.ergalieva@qamqor.kz`
- Demo doctor password: `doctor12345`

## Main Endpoints

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/doctors`
- `POST /api/v1/doctors`
- `PATCH /api/v1/doctors/me`
- `POST /api/v1/appointments`
- `GET /api/v1/appointments`
- `PATCH /api/v1/appointments/{appointment_id}/status`
- `GET /api/v1/cycle`
- `POST /api/v1/cycle`
- `GET /api/v1/chats/{chat_id}/messages`
- `POST /api/v1/chats/{chat_id}/messages`
