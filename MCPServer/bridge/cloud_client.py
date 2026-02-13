"""
Cloud worker HTTP client for the Claude Watch bridge.

Handles bidirectional sync between the local bridge and the cloud worker:

- **Push**: Bridge pushes approval/question/progress state TO cloud when CLI
  events arrive.  This lets the watch poll cloud as before (zero watch changes).
- **Poll**: Bridge polls cloud for watch responses — approval decisions,
  question answers, interrupt commands, and session-end.

No new cloud worker endpoints are needed.  The bridge reuses the same
``POST /approval``, ``POST /question``, ``POST /session-progress``, etc.
that the old hook-based system used.

Reference: .claude/plans/sdk-url-agent-execution-spec.md — Task B2
"""
from __future__ import annotations

import asyncio
import logging
import os
from typing import Any

import aiohttp

from MCPServer.bridge.api import _permission_to_watch_request
from MCPServer.bridge.questions import extract_recommendation, is_ask_user_question

logger = logging.getLogger("bridge.cloud_client")


# ---------------------------------------------------------------------------
# Shim so we can reuse _permission_to_watch_request which expects .tool_name
# and .input attributes.
# ---------------------------------------------------------------------------

class _PermShim:
    """Lightweight stand-in for PermissionRequest attributes."""

    __slots__ = ("tool_name", "input")

    def __init__(self, tool_name: str, tool_input: dict) -> None:
        self.tool_name = tool_name
        self.input = tool_input


class CloudClient:
    """HTTP client for syncing bridge state with the cloud worker.

    The cloud worker acts as a relay between the bridge (developer's machine)
    and the Apple Watch (polling from anywhere).

    Lifecycle::

        client = CloudClient("https://remmy.watch", "pair-abc-123")
        await client.start()
        # ... push / poll ...
        await client.stop()
    """

    def __init__(
        self,
        cloud_url: str,
        pairing_id: str,
        *,
        poll_interval: float = 2.0,
        retry_attempts: int = 2,
        retry_delay: float = 1.0,
    ) -> None:
        self.cloud_url = cloud_url.rstrip("/")
        self.pairing_id = pairing_id
        self.poll_interval = poll_interval
        self._retry_attempts = retry_attempts
        self._retry_delay = retry_delay
        self._session: aiohttp.ClientSession | None = None
        self._enabled = True

    async def start(self) -> None:
        """Create the aiohttp session."""
        self._session = aiohttp.ClientSession()

    async def stop(self) -> None:
        """Close the aiohttp session."""
        if self._session:
            await self._session.close()
            self._session = None

    @property
    def is_enabled(self) -> bool:
        """True when the client is operational."""
        return self._enabled and self._session is not None

    def disable(self) -> None:
        """Disable cloud sync (e.g. after repeated failures)."""
        self._enabled = False
        logger.warning("Cloud sync disabled for pairing %s", self.pairing_id)

    # ------------------------------------------------------------------
    # Push: Bridge → Cloud
    # ------------------------------------------------------------------

    async def push_approval(
        self,
        request_id: str,
        tool_name: str,
        tool_input: dict[str, Any],
    ) -> bool:
        """Push a tool approval request to the cloud worker.

        Calls ``POST /approval`` with the same schema the watch expects.
        """
        watch_req = _permission_to_watch_request(
            request_id, _PermShim(tool_name, tool_input)
        )
        payload: dict[str, Any] = {
            "pairingId": self.pairing_id,
            **watch_req,
        }
        return await self._post("/approval", payload)

    async def push_question(
        self,
        request_id: str,
        input_data: dict[str, Any],
    ) -> bool:
        """Push an AskUserQuestion to the cloud worker.

        Calls ``POST /question`` using the cloud's expected schema (with
        ``options`` array, not the bridge's ``allOptions`` flat list).
        """
        questions = input_data.get("questions", [])
        first = questions[0] if questions else {}
        options = first.get("options", [])

        payload: dict[str, Any] = {
            "pairingId": self.pairing_id,
            "questionId": request_id,
            "question": first.get("question", ""),
            "header": first.get("header", ""),
            "options": options,
            "multiSelect": first.get("multiSelect", False),
            "recommendedAnswer": extract_recommendation(first),
        }
        return await self._post("/question", payload)

    async def push_progress(self, progress: dict[str, Any]) -> bool:
        """Push session progress to the cloud worker.

        Calls ``POST /session-progress`` with the standard progress payload.
        """
        payload: dict[str, Any] = {
            "pairingId": self.pairing_id,
            **progress,
        }
        return await self._post("/session-progress", payload)

    # ------------------------------------------------------------------
    # Poll: Cloud → Bridge  (watch responses)
    # ------------------------------------------------------------------

    async def poll_approval_status(self, request_id: str) -> str | None:
        """Check cloud for an approval response.

        Returns ``"approved"``, ``"rejected"``, or ``None`` if still pending.
        """
        data = await self._get(
            f"/approval/{self.pairing_id}/{request_id}"
        )
        if data is None:
            return None
        status = data.get("status")
        if status in ("approved", "rejected"):
            return status
        return None

    async def poll_question_status(self, question_id: str) -> dict | None:
        """Check cloud for a question answer.

        Returns ``{"status": "answered", "answer": ...}`` or ``None``.
        """
        data = await self._get(
            f"/question/{self.pairing_id}/{question_id}"
        )
        if data is None:
            return None
        if data.get("status") == "answered":
            return data
        return None

    async def poll_interrupt_state(self) -> dict:
        """Check cloud for interrupt state changes.

        Returns ``{"interrupted": bool, "action": str|None}``.
        """
        data = await self._get(
            f"/session-interrupt/{self.pairing_id}"
        )
        return data or {"interrupted": False, "action": None}

    async def poll_session_active(self) -> bool:
        """Check cloud for session-end from the watch.

        Returns ``False`` if the watch ended the session.
        """
        data = await self._get(
            f"/session-status/{self.pairing_id}"
        )
        if data is None:
            return True  # Assume active if cloud unreachable
        return data.get("sessionActive", True)

    # ------------------------------------------------------------------
    # HTTP helpers
    # ------------------------------------------------------------------

    async def _post(self, path: str, payload: dict) -> bool:
        """POST JSON to cloud.  Returns ``True`` on 2xx."""
        if not self.is_enabled:
            return False

        url = f"{self.cloud_url}{path}"
        for attempt in range(self._retry_attempts + 1):
            try:
                async with self._session.post(url, json=payload) as resp:
                    if resp.status < 300:
                        return True
                    logger.warning(
                        "POST %s returned %d (attempt %d)",
                        path,
                        resp.status,
                        attempt + 1,
                    )
                    return False
            except Exception as exc:
                if attempt < self._retry_attempts:
                    await asyncio.sleep(self._retry_delay * (attempt + 1))
                else:
                    logger.warning("POST %s failed after %d attempts: %s",
                                   path, attempt + 1, exc)
                    return False
        return False

    async def _get(self, path: str) -> dict | None:
        """GET JSON from cloud.  Returns parsed dict or ``None``."""
        if not self.is_enabled:
            return None

        url = f"{self.cloud_url}{path}"
        for attempt in range(self._retry_attempts + 1):
            try:
                async with self._session.get(url) as resp:
                    if resp.status < 300:
                        return await resp.json()
                    return None
            except Exception as exc:
                if attempt < self._retry_attempts:
                    await asyncio.sleep(self._retry_delay * (attempt + 1))
                else:
                    logger.debug("GET %s failed: %s", path, exc)
                    return None
        return None
