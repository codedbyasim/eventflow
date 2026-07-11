"""
Fireworks AI async client wrapper.
- Calls the OpenAI-compatible chat completions endpoint.
- Implements retry with exponential backoff (NFR-REL-01).
- Writes a row to llm_usage_log after every call (FR-DAT-02, NFR-MNT-02).
- Model is read from config — never hardcoded (feedback point #1).
"""
from __future__ import annotations

import json
import logging
import time
import uuid
from typing import Any

import httpx
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
    before_sleep_log,
)

from app.config import get_settings
from app.db import db_session
from app.models.llm_usage_log import LLMUsageLog

logger = logging.getLogger(__name__)

# Approximate cost per 1K tokens (USD) — update when pricing changes
# These are rough estimates; actual billing is on the Fireworks dashboard
_COST_PER_1K_INPUT_USD = 0.0009
_COST_PER_1K_OUTPUT_USD = 0.0009


class FireworksError(Exception):
    """Raised when the Fireworks API returns a non-2xx response after all retries."""


@retry(
    retry=retry_if_exception_type((httpx.TransportError, httpx.TimeoutException, FireworksError)),
    wait=wait_exponential(multiplier=1, min=2, max=30),
    stop=stop_after_attempt(4),
    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)
async def call_fireworks(
    *,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]],
    agent_type: str,          # "analyzer" | "negotiation" | "aggregator"
    event_id: uuid.UUID | None = None,
    negotiation_id: uuid.UUID | None = None,
    tool_choice: str = "required",   # force a tool call on every invocation
    max_tokens: int = 4096,
) -> dict[str, Any]:
    """
    Make a single Fireworks AI chat completion call with function calling.

    Returns the parsed tool-call arguments dict for the first tool call in the response.
    Raises FireworksError on API failure after exhausting retries.

    Logs cost/token data to llm_usage_log after every call (success or failure).
    """
    settings = get_settings()
    start_ms = int(time.monotonic() * 1000)
    success = True
    error_message: str | None = None
    tokens_in = tokens_out = 0
    tool_args: dict[str, Any] = {}

    # Determine tool choice to guarantee function call for single-tool agents
    resolved_tool_choice = tool_choice
    if agent_type == "analyzer":
        resolved_tool_choice = {"type": "function", "function": {"name": "allocate_budget"}}
    elif agent_type == "aggregator":
        resolved_tool_choice = {"type": "function", "function": {"name": "compile_package"}}

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                f"{settings.fireworks_base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.fireworks_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.fireworks_model,
                    "messages": messages,
                    "tools": tools,
                    "tool_choice": resolved_tool_choice,
                    "temperature": 0.2,     # low temperature for deterministic tool calls
                    "max_tokens": max_tokens,
                },
            )

        if resp.status_code != 200:
            error_message = f"HTTP {resp.status_code}: {resp.text[:400]}"
            success = False
            raise FireworksError(error_message)

        data = resp.json()
        usage = data.get("usage", {})
        tokens_in = usage.get("prompt_tokens", 0)
        tokens_out = usage.get("completion_tokens", 0)

        # Extract first tool call
        choices = data.get("choices", [])
        if not choices:
            raise FireworksError("No choices in Fireworks response")

        message = choices[0].get("message", {})
        tool_calls = message.get("tool_calls", [])
        if not tool_calls:
            # Model responded with text instead of a tool call — treat as error
            content = message.get("content", "")
            raise FireworksError(f"Model did not return a tool call. Content: {content[:200]}")

        raw_args = tool_calls[0]["function"].get("arguments", "{}")
        tool_args = json.loads(raw_args) if isinstance(raw_args, str) else raw_args
        tool_name = tool_calls[0]["function"]["name"]

        logger.info(
            "[%s] tool=%s tokens=%d+%d event=%s",
            agent_type, tool_name, tokens_in, tokens_out, event_id,
        )
        return tool_args

    except (FireworksError, httpx.TransportError, httpx.TimeoutException):
        success = False
        raise

    except Exception as exc:
        success = False
        error_message = str(exc)
        logger.exception("[%s] Unexpected error calling Fireworks AI", agent_type)
        raise FireworksError(f"Unexpected error: {exc}") from exc

    finally:
        # Always log usage, even on failure (FR-DAT-02, NFR-MNT-02)
        latency_ms = int(time.monotonic() * 1000) - start_ms
        cost = (
            (tokens_in / 1000 * _COST_PER_1K_INPUT_USD)
            + (tokens_out / 1000 * _COST_PER_1K_OUTPUT_USD)
        )
        try:
            async with db_session() as db:
                db.add(LLMUsageLog(
                    id=uuid.uuid4(),
                    agent_type=agent_type,  # type: ignore[arg-type]
                    event_id=event_id,
                    negotiation_id=negotiation_id,
                    model_used=get_settings().fireworks_model,
                    tokens_in=tokens_in,
                    tokens_out=tokens_out,
                    cost_usd=cost,
                    latency_ms=latency_ms,
                    success=success,
                    error_message=error_message,
                ))
        except Exception as log_exc:
            # Never let a logging failure crash the main flow
            logger.warning("Failed to write llm_usage_log: %s", log_exc)
