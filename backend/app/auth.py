"""
Firebase Admin SDK initialisation + ID-token verification middleware.
FR-AUTH-05: Backend verifies Firebase ID token on every API request.
NFR-SEC-03: Role-based authorization enforced here.
"""
from __future__ import annotations

import logging
from functools import lru_cache

import firebase_admin
from firebase_admin import auth, credentials, firestore
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import get_settings

logger = logging.getLogger(__name__)
_bearer = HTTPBearer(auto_error=True)


# ── Firebase app singleton ────────────────────────────────────────────────────

@lru_cache(maxsize=1)
def _get_firebase_app() -> firebase_admin.App:
    settings = get_settings()
    cred = credentials.Certificate(settings.firebase_credentials_dict)
    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app(cred)


def get_firestore_client():
    """Return the Firestore async client (shared singleton)."""
    _get_firebase_app()
    return firestore.client()


# ── Token verification ────────────────────────────────────────────────────────

class FirebaseUser:
    """Decoded Firebase ID-token payload attached to every authenticated request."""

    def __init__(self, uid: str, email: str | None, role: str | None):
        self.uid = uid
        self.email = email
        self.role = role  # "customer" | "vendor" — read from Firestore users/{uid}

    def require_role(self, *roles: str) -> None:
        if self.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires role: {' or '.join(roles)}. Your role: {self.role}",
            )


async def _fetch_role(uid: str) -> str | None:
    """Look up the user's role from Firestore users/{uid}.role."""
    try:
        db = get_firestore_client()
        doc = db.collection("users").document(uid).get()
        if doc.exists:
            return doc.to_dict().get("role")
    except Exception as exc:
        logger.warning("Could not fetch role for uid=%s: %s", uid, exc)
    return None


async def verify_token(
    creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> FirebaseUser:
    """
    FastAPI dependency: extracts Bearer token, verifies it with Firebase Auth,
    and returns a FirebaseUser with the decoded uid + role.
    Raises HTTP 401 on invalid/expired tokens.
    """
    token = creds.credentials
    try:
        _get_firebase_app()
        decoded = auth.verify_id_token(token)
    except auth.ExpiredIdTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except auth.InvalidIdTokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {exc}")
    except Exception as exc:
        logger.error("Token verification error: %s", exc)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication failed")

    uid = decoded["uid"]
    role = await _fetch_role(uid)
    return FirebaseUser(uid=uid, email=decoded.get("email"), role=role)


# ── Convenience role-gated dependencies ──────────────────────────────────────

async def require_customer(user: FirebaseUser = Depends(verify_token)) -> FirebaseUser:
    user.require_role("customer")
    return user


async def require_vendor(user: FirebaseUser = Depends(verify_token)) -> FirebaseUser:
    user.require_role("vendor")
    return user
