"""
EventFlow Backend — Configuration
All settings loaded from environment variables (never hardcoded).
NFR-SEC-02: Fireworks AI key and Firebase credentials live only here.
"""
from __future__ import annotations

import json
import base64
from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parent.parent / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── App ──────────────────────────────────────────────────────────
    app_env: Literal["development", "staging", "production"] = "development"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    secret_key: str = "change-me"

    # ── Database ─────────────────────────────────────────────────────
    database_url: str = Field(
        "",
        description="PgBouncer transaction pooler connection DSN"
    )
    direct_database_url: str | None = Field(
        None,
        description="Direct connection DSN for Alembic migrations"
    )

    # ── Firebase ─────────────────────────────────────────────────────
    # Provide one of:
    #   FIREBASE_SERVICE_ACCOUNT_PATH  — path to the JSON file
    #   FIREBASE_SERVICE_ACCOUNT_JSON  — base64-encoded JSON string
    firebase_service_account_path: str | None = None
    firebase_service_account_json: str | None = None  # base64-encoded

    # ── Fireworks AI (NFR-SEC-02) ─────────────────────────────────────
    fireworks_api_key: str = ""
    fireworks_base_url: str = "https://api.fireworks.ai/inference/v1"
    # Model must be set via env — checked against live Fireworks catalog at deploy time.
    # See .env.example for current recommended options.
    fireworks_model: str = "accounts/fireworks/models/kimi-k2p6"

    # ── Agent Tuning ─────────────────────────────────────────────────
    max_negotiation_rounds: int = 5       # FR-NEG-02
    vendor_timeout_secs: int = 300        # FR-NEG-06
    vendors_per_category: int = 3         # FR-MTC-03
    reconciliation_interval_secs: int = 60

    # ── Dynamic Pricing Multipliers ──────────────────────────────────
    caterer_tent_seating_cost: float = 300.0
    decor_outdoor_multiplier: float = 1.25
    decor_guest_threshold: int = 100
    decor_guest_multiplier_rate: float = 0.05
    flowers_guest_threshold: int = 100

    # ── Rate Limiting ────────────────────────────────────────────────
    rate_limit_event_create: str = "5/minute"  # NFR-SEC-05
    rate_limit_vendor_reply: str = "30/minute"



    # ── Derived helpers ───────────────────────────────────────────────
    @property
    def firebase_credentials_dict(self) -> dict:
        """Resolve Firebase credentials from env — path or base64 JSON."""
        if self.firebase_service_account_json:
            raw = base64.b64decode(self.firebase_service_account_json).decode()
            return json.loads(raw)
        if self.firebase_service_account_path:
            path = Path(self.firebase_service_account_path)
            if not path.is_absolute() and not path.exists():
                # Fallback: try relative to the backend root directory
                alt_path = Path(__file__).resolve().parent.parent / path
                if alt_path.exists():
                    path = alt_path
            if path.exists():
                return json.loads(path.read_text())
        raise RuntimeError(
            "Firebase credentials not configured. Set FIREBASE_SERVICE_ACCOUNT_PATH "
            "or FIREBASE_SERVICE_ACCOUNT_JSON in .env"
        )

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @model_validator(mode="after")
    def _validate_fireworks_key(self) -> "Settings":
        if not self.fireworks_api_key:
            import warnings
            warnings.warn(
                "FIREWORKS_API_KEY is not set. Agent calls will fail.",
                stacklevel=2,
            )
        return self


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
