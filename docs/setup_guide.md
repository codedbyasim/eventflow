# Setup & Installation Guide

This document details the configuration and run commands for the EventFlow Flutter application and FastAPI backend.

---

## 1. Prerequisites
* **Flutter SDK**: `^3.22.0` (Dart `^3.4.0`)
* **Python**: `^3.10` (with Poetry package manager recommended)
* **Supabase / PostgreSQL**: Free instance or local Postgres server.
* **Firebase Project**: Firestore, Authentication, and Firebase Cloud Messaging enabled.

---

## 2. Backend Setup

### A. Environment Configuration
Create a `.env` file inside the `backend` folder:
```env
# Database Credentials
DATABASE_URL=postgresql+asyncpg://postgres:your-supabase-password@db.xxxx.supabase.co:5432/postgres
DIRECT_DATABASE_URL=postgresql://postgres:your-supabase-password@db.xxxx.supabase.co:5432/postgres

# Firebase Admin SDK Configuration
FIREBASE_SERVICE_ACCOUNT_JSON={"type": "service_account", "project_id": "amdhack-aa788", ...}

# LLM Provider Configuration
FIREWORKS_API_KEY=your-fireworks-ai-api-key
```

### B. Install Dependencies
Open your terminal in the workspace root and run:
```bash
cd backend
poetry install
```

### C. Run Database Migrations
We use Alembic to manage PostgreSQL schemas. Run:
```bash
poetry run alembic upgrade head
```

### D. Clear and Seed (Testing)
If you want to clear previous testing data or seed vendors in PostgreSQL:
* **Clear DB**: Wipes Postgres and Firestore clean:
  ```bash
  poetry run python scripts/clear_all.py
  ```
* **Seed Vendors**: Inserts default service providers into PostgreSQL:
  ```bash
  poetry run python scripts/seed_vendors.py
  ```

### E. Run the Backend Server
Start the Uvicorn dev server:
```bash
poetry run uvicorn app.main:create_app --app-dir backend --host 0.0.0.0 --port 8000 --reload
```

---

## 3. Flutter Client Setup

### A. Firebase Configuration
Verify you have the Firebase CLI configured. If `firebase_options.dart` or `google-services.json` are missing:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=amdhack-aa788
```

### B. Install Packages
```bash
flutter pub get
```

### C. Localization Setup
We use `easy_localization`. If you add new translation keys in `assets/lang/en.json` or `assets/lang/ur.json`, run:
```bash
flutter pub run easy_localization:generate -O lib/core/localization -f keys -o locale_keys.g.dart
```

### D. Run the App
Launch the app in debug mode on your connected emulator:
```bash
flutter run
```
*Note: The app defaults to the deployed backend at `https://eventflow-backend-3x0m.onrender.com`. For local development, you can override it with `BACKEND_URL` (for example `http://10.0.2.2:8000` for the Android Emulator).*
