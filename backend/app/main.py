"""
EventFlow Backend — FastAPI Application Entry Point
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.auth import _get_firebase_app
from app.config import get_settings
from app.limiter import limiter

logger = logging.getLogger(__name__)


# ── Application lifespan ──────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup + shutdown hooks."""
    settings = get_settings()
    logger.info("Starting EventFlow backend (env=%s)", settings.app_env)

    # Initialize Firebase Admin SDK
    try:
        _get_firebase_app()
        logger.info("Firebase Admin SDK initialized")
    except Exception as exc:
        logger.error("Firebase init failed: %s", exc)

    # Start reconciliation scheduler (Phase 3 — imported lazily to avoid circular deps)
    try:
        from app.services.reconciliation import start_reconciliation_scheduler
        start_reconciliation_scheduler()
        logger.info("Reconciliation scheduler started")
    except ImportError:
        logger.info("Reconciliation scheduler not yet implemented — skipping")

    yield

    logger.info("Shutting down EventFlow backend")


# ── FastAPI app ───────────────────────────────────────────────────────────────
def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="EventFlow API",
        description="AI-Agent-Driven Event Planning & Vendor Negotiation Backend",
        version="1.0.0",
        docs_url="/docs" if not settings.is_production else None,
        redoc_url="/redoc" if not settings.is_production else None,
        lifespan=lifespan,
    )

    # Rate limiting
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # CORS — Flutter web + mobile dev
    allowed_origins = ["http://localhost:*", "http://127.0.0.1:*"]
    if settings.is_production:
        allowed_origins = []  # Lock down in production

    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["Authorization", "Content-Type"],
    )

    # ── Routers (registered here; implemented in Phase 3) ─────────────────
    try:
        from app.routers import events, negotiations, bookings, users
        app.include_router(events.router, prefix="/events", tags=["Events"])
        app.include_router(negotiations.router, prefix="/negotiations", tags=["Negotiations"])
        app.include_router(bookings.router, prefix="/bookings", tags=["Bookings"])
        app.include_router(users.router, prefix="/users", tags=["Users"])
    except ImportError as exc:
        logger.warning("Routers not yet available: %s", exc)

    @app.get("/health", tags=["Health"])
    async def health():
        return {"status": "ok", "service": "eventflow-backend"}

    return app


app = create_app()


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    settings = get_settings()
    uvicorn.run(
        "app.main:app",
        host=settings.app_host,
        port=settings.app_port,
        reload=(settings.app_env == "development"),
        log_level="info",
    )
