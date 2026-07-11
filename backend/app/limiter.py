"""
Shared SlowAPI Limiter instance to avoid circular imports between app.main and routers.
"""
from __future__ import annotations

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
