"""WebSocket server that speaks NDJSON with Claude Code CLI.

Accepts connections on /ws/cli/{session_id}, parses newline-delimited JSON
messages, and dispatches them to registered handlers by message type.

Part of the SDK-URL migration (spec task A1).
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any, Callable, Awaitable

from websockets.asyncio.server import serve, ServerConnection

logger = logging.getLogger("bridge.ndjson")

# Type aliases for handler callbacks
MessageHandler = Callable[[str, dict[str, Any]], Awaitable[None]]
ConnectHandler = Callable[[str, ServerConnection], Awaitable[None]]
DisconnectHandler = Callable[[str], Awaitable[None]]


class NDJSONServer:
    """WebSocket server that speaks NDJSON with Claude Code CLI.

    Listens for WebSocket connections on ``/ws/cli/{session_id}``.  Each
    incoming WebSocket frame is split on ``\\n`` and every non-empty line
    is parsed as JSON.  Parsed messages are dispatched to handlers
    registered via :meth:`on_message` keyed by ``msg["type"]``.

    ``keep_alive`` messages are silently consumed.  Malformed JSON lines
    are logged and skipped — they never crash the server.
    """

    def __init__(self, host: str = "localhost", port: int = 8787) -> None:
        self.host = host
        self.port = port

        # Handler registry: msg_type -> async callable(session_id, msg_dict)
        self._handlers: dict[str, MessageHandler] = {}

        # Lifecycle callbacks
        self._on_connect: ConnectHandler | None = None
        self._on_disconnect: DisconnectHandler | None = None

        # Active CLI sockets: session_id -> ServerConnection
        self._cli_sockets: dict[str, ServerConnection] = {}

        # Server handle (set after start())
        self._server: Any = None

    # ------------------------------------------------------------------
    # Registration API
    # ------------------------------------------------------------------

    def on_message(self, msg_type: str, handler: MessageHandler) -> None:
        """Register an async handler for a specific message type."""
        self._handlers[msg_type] = handler

    def on_connect(self, handler: ConnectHandler) -> None:
        """Register an async callback invoked when a CLI connects."""
        self._on_connect = handler

    def on_disconnect(self, handler: DisconnectHandler) -> None:
        """Register an async callback invoked when a CLI disconnects."""
        self._on_disconnect = handler

    # ------------------------------------------------------------------
    # Connection handler
    # ------------------------------------------------------------------

    async def _handle_connection(self, websocket: ServerConnection) -> None:
        """Handle a single CLI WebSocket connection."""

        # Extract session_id from URL path: /ws/cli/{session_id}
        path: str = websocket.request.path  # type: ignore[union-attr]
        parts = path.strip("/").split("/")

        if len(parts) != 3 or parts[0] != "ws" or parts[1] != "cli":
            logger.warning("Rejected connection with invalid path: %s", path)
            await websocket.close(4000, "Invalid path")
            return

        session_id = parts[2]
        if not session_id:
            logger.warning("Rejected connection with empty session_id")
            await websocket.close(4000, "Empty session_id")
            return

        self._cli_sockets[session_id] = websocket
        logger.info("CLI connected for session %s", session_id)

        if self._on_connect is not None:
            try:
                await self._on_connect(session_id, websocket)
            except Exception:
                logger.exception(
                    "on_connect callback failed for session %s", session_id
                )

        try:
            async for raw_message in websocket:
                data: str = (
                    raw_message
                    if isinstance(raw_message, str)
                    else raw_message.decode("utf-8")
                )
                await self._process_frame(session_id, data)
        except Exception:
            # websockets raises ConnectionClosed variants on disconnect;
            # catch everything so we always reach the finally block.
            logger.info("CLI connection ended for session %s", session_id)
        finally:
            self._cli_sockets.pop(session_id, None)
            logger.info("CLI disconnected for session %s", session_id)

            if self._on_disconnect is not None:
                try:
                    await self._on_disconnect(session_id)
                except Exception:
                    logger.exception(
                        "on_disconnect callback failed for session %s",
                        session_id,
                    )

    async def _process_frame(self, session_id: str, data: str) -> None:
        """Split a WebSocket frame into NDJSON lines and dispatch each."""
        for line in data.split("\n"):
            line = line.strip()
            if not line:
                continue

            # Parse JSON — skip malformed lines
            try:
                msg: dict[str, Any] = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                logger.warning(
                    "Malformed NDJSON line from session %s: %.200s",
                    session_id,
                    line,
                )
                continue

            msg_type = msg.get("type")
            if not msg_type:
                logger.warning(
                    "Message without type from session %s: %.200s",
                    session_id,
                    line,
                )
                continue

            # Silently consume keep_alive
            if msg_type == "keep_alive":
                continue

            handler = self._handlers.get(msg_type)
            if handler is not None:
                try:
                    await handler(session_id, msg)
                except Exception:
                    logger.exception(
                        "Handler error for type=%s in session %s",
                        msg_type,
                        session_id,
                    )
            else:
                logger.debug(
                    "No handler registered for message type %s (session %s)",
                    msg_type,
                    session_id,
                )

    # ------------------------------------------------------------------
    # Outbound API
    # ------------------------------------------------------------------

    async def send_to_cli(self, session_id: str, msg: dict[str, Any]) -> bool:
        """Send an NDJSON message to a CLI session.

        Returns ``True`` if the message was sent, ``False`` otherwise
        (e.g. no active socket for *session_id*).
        """
        ws = self._cli_sockets.get(session_id)
        if ws is None:
            logger.warning("No CLI socket for session %s", session_id)
            return False
        try:
            payload = json.dumps(msg) + "\n"
            await ws.send(payload)
            return True
        except Exception:
            logger.exception(
                "Failed to send to CLI session %s", session_id
            )
            return False

    def is_cli_connected(self, session_id: str) -> bool:
        """Return ``True`` if a CLI socket is active for *session_id*."""
        return session_id in self._cli_sockets

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    async def start(self) -> Any:
        """Start the WebSocket server. Returns the server object."""
        self._server = await serve(
            self._handle_connection,
            self.host,
            self.port,
            ping_interval=10,
            ping_timeout=10,
        )
        logger.info(
            "NDJSON server listening on ws://%s:%d", self.host, self.port
        )
        return self._server

    async def stop(self) -> None:
        """Gracefully stop the server."""
        if self._server is not None:
            self._server.close()
            await self._server.wait_closed()
            self._server = None
            logger.info("NDJSON server stopped")
