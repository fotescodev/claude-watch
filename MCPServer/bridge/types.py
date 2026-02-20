"""
Type definitions for all NDJSON message types from Claude Code CLI.

These dataclasses model the WebSocket protocol messages sent by the CLI
when launched with --sdk-url. Field names use snake_case; the parse_cli_message()
function handles camelCase -> snake_case conversion from the wire format.

Reference: /tmp/remmy-websocket/WEBSOCKET_PROTOCOL_REVERSED.md
"""
from __future__ import annotations

import logging
import re
from dataclasses import MISSING, dataclass, field, fields
from typing import Any, Union

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Content blocks (used inside assistant message.content)
# ---------------------------------------------------------------------------

@dataclass
class TextBlock:
    """A text content block in an assistant message."""
    type: str  # "text"
    text: str


@dataclass
class ToolUseBlock:
    """A tool_use content block — the assistant is invoking a tool."""
    type: str  # "tool_use"
    id: str
    name: str
    input: dict


@dataclass
class ToolResultBlock:
    """A tool_result content block — result returned from tool execution."""
    type: str  # "tool_result"
    tool_use_id: str
    content: Any  # str or list of content blocks
    is_error: bool = False


# Union of possible content block types. Unknown block types fall through as dict.
ContentBlock = Union[TextBlock, ToolUseBlock, ToolResultBlock, dict]


# ---------------------------------------------------------------------------
# CLI -> Server message types
# ---------------------------------------------------------------------------

@dataclass
class SystemInitMessage:
    """First message from CLI after WebSocket connect (type=system, subtype=init)."""
    type: str  # "system"
    subtype: str  # "init"
    session_id: str
    model: str
    cwd: str
    tools: list[str]
    permission_mode: str  # wire: permissionMode
    claude_code_version: str
    mcp_servers: list[dict]
    slash_commands: list[str]
    uuid: str
    agents: list[str] = field(default_factory=list)
    skills: list[str] = field(default_factory=list)


@dataclass
class SystemStatusMessage:
    """Status update from CLI (type=system, subtype=status)."""
    type: str  # "system"
    subtype: str  # "status"
    status: str | None  # "compacting" or None
    uuid: str
    session_id: str
    permission_mode: str | None = None  # wire: permissionMode


@dataclass
class AssistantMessage:
    """Full assistant response (type=assistant). message contains id, role, model, content, etc."""
    type: str  # "assistant"
    message: dict  # {id, role, model, content: list[ContentBlock], stop_reason, usage}
    parent_tool_use_id: str | None
    uuid: str
    session_id: str
    error: str | None = None


@dataclass
class ResultMessage:
    """Query completion (type=result). Carries cost, turns, usage, context info."""
    type: str  # "result"
    subtype: str  # "success" | "error_during_execution" | "error_max_turns" | "error_max_budget_usd"
    is_error: bool
    duration_ms: int
    duration_api_ms: int
    num_turns: int
    total_cost_usd: float
    stop_reason: str | None
    usage: dict
    uuid: str
    session_id: str
    result: str | None = None  # present on success subtype
    errors: list[str] | None = None  # present on error subtypes
    model_usage: dict | None = None  # wire: modelUsage


@dataclass
class ControlRequestMessage:
    """Control request (type=control_request). Contains request_id and request payload."""
    type: str  # "control_request"
    request_id: str
    request: dict  # {subtype, tool_name, input, tool_use_id, ...}


@dataclass
class StreamEventMessage:
    """Streaming token event (type=stream_event). Only sent with --verbose."""
    type: str  # "stream_event"
    event: dict
    parent_tool_use_id: str | None
    uuid: str
    session_id: str


@dataclass
class ToolProgressMessage:
    """Tool execution heartbeat (type=tool_progress)."""
    type: str  # "tool_progress"
    tool_use_id: str
    tool_name: str
    parent_tool_use_id: str | None
    elapsed_time_seconds: float
    uuid: str
    session_id: str


@dataclass
class ToolUseSummaryMessage:
    """Tool execution summary (type=tool_use_summary)."""
    type: str  # "tool_use_summary"
    summary: str
    preceding_tool_use_ids: list[str]
    uuid: str
    session_id: str


@dataclass
class AuthStatusMessage:
    """Authentication flow status (type=auth_status)."""
    type: str  # "auth_status"
    is_authenticating: bool  # wire: isAuthenticating
    output: list[str]
    uuid: str
    session_id: str
    error: str | None = None


@dataclass
class KeepAliveMessage:
    """Keepalive ping (type=keep_alive). No payload."""
    type: str  # "keep_alive"


# ---------------------------------------------------------------------------
# camelCase -> snake_case mapping
# ---------------------------------------------------------------------------

# Explicit mapping for known camelCase fields from the wire protocol.
# Keys are the wire (camelCase) names, values are the Python (snake_case) names.
_CAMEL_TO_SNAKE: dict[str, str] = {
    "permissionMode": "permission_mode",
    "isAuthenticating": "is_authenticating",
    "modelUsage": "model_usage",
    "parentToolUseId": "parent_tool_use_id",
    "toolUseId": "tool_use_id",
    "toolName": "tool_name",
    "elapsedTimeSeconds": "elapsed_time_seconds",
    "requestId": "request_id",
    "precedingToolUseIds": "preceding_tool_use_ids",
    "sessionId": "session_id",
    "mcpServers": "mcp_servers",
    "slashCommands": "slash_commands",
    "claudeCodeVersion": "claude_code_version",
    "isError": "is_error",
    "totalCostUsd": "total_cost_usd",
    "numTurns": "num_turns",
    "durationMs": "duration_ms",
    "durationApiMs": "duration_api_ms",
    "stopReason": "stop_reason",
}

# Regex-based fallback: convert any remaining camelCase to snake_case.
_CAMEL_RE_1 = re.compile(r"(.)([A-Z][a-z]+)")
_CAMEL_RE_2 = re.compile(r"([a-z0-9])([A-Z])")


def _camel_to_snake(name: str) -> str:
    """Convert a camelCase string to snake_case."""
    if name in _CAMEL_TO_SNAKE:
        return _CAMEL_TO_SNAKE[name]
    s = _CAMEL_RE_1.sub(r"\1_\2", name)
    return _CAMEL_RE_2.sub(r"\1_\2", s).lower()


def _convert_keys(raw: dict) -> dict:
    """Convert all top-level keys from camelCase to snake_case."""
    return {_camel_to_snake(k): v for k, v in raw.items()}


# ---------------------------------------------------------------------------
# Message type dispatch table
# ---------------------------------------------------------------------------

# Map (type, subtype?) -> dataclass. For "system" messages we dispatch on subtype.
_SYSTEM_SUBTYPES: dict[str, type] = {
    "init": SystemInitMessage,
    "status": SystemStatusMessage,
}

_TYPE_MAP: dict[str, type] = {
    "assistant": AssistantMessage,
    "result": ResultMessage,
    "control_request": ControlRequestMessage,
    "stream_event": StreamEventMessage,
    "tool_progress": ToolProgressMessage,
    "tool_use_summary": ToolUseSummaryMessage,
    "auth_status": AuthStatusMessage,
    "keep_alive": KeepAliveMessage,
}


def _safe_build(cls: type, data: dict) -> Any:
    """Build a dataclass instance, being lenient about missing/extra fields.

    - Extra keys in *data* that are not dataclass fields are silently ignored.
    - Missing fields that have a default or default_factory are left to the
      dataclass constructor.
    - Missing *required* fields (no default at all) get a sensible zero-value
      so that the constructor never raises TypeError.
    """
    valid_field_names = {f.name for f in fields(cls)}
    filtered = {k: v for k, v in data.items() if k in valid_field_names}

    # Fill in missing required fields with zero-values
    for f in fields(cls):
        if f.name in filtered:
            continue
        # If the field has a default or default_factory, the constructor handles it
        if f.default is not MISSING or f.default_factory is not MISSING:
            continue
        # Truly required — supply a fallback based on the type annotation
        type_str = str(f.type)
        if "None" in type_str:
            filtered[f.name] = None
        elif type_str in ("str",):
            filtered[f.name] = ""
        elif type_str in ("int",):
            filtered[f.name] = 0
        elif type_str in ("float",):
            filtered[f.name] = 0.0
        elif type_str in ("bool",):
            filtered[f.name] = False
        elif type_str in ("dict",):
            filtered[f.name] = {}
        elif "list" in type_str:
            filtered[f.name] = []
        else:
            filtered[f.name] = None

    return cls(**filtered)


def parse_cli_message(raw: dict) -> Any:
    """Parse a raw JSON dict from the CLI into the appropriate typed dataclass.

    Handles camelCase -> snake_case conversion for known fields.
    Unknown message types are returned as-is (the raw dict).
    Missing optional fields get defaults; unknown extra fields are ignored.

    Args:
        raw: Parsed JSON dict from a single NDJSON line.

    Returns:
        A typed dataclass instance, or the raw dict if the type is unrecognized.
    """
    msg_type = raw.get("type")

    if msg_type == "keep_alive":
        return KeepAliveMessage(type="keep_alive")

    # Convert camelCase keys to snake_case
    converted = _convert_keys(raw)

    if msg_type == "system":
        subtype = converted.get("subtype")
        cls = _SYSTEM_SUBTYPES.get(subtype)  # type: ignore[arg-type]
        if cls is None:
            # Unknown system subtype — return raw dict
            logger.debug("Unknown system subtype: %s", subtype)
            return raw
        return _safe_build(cls, converted)

    cls = _TYPE_MAP.get(msg_type)  # type: ignore[arg-type]
    if cls is None:
        logger.debug("Unknown message type: %s", msg_type)
        return raw

    return _safe_build(cls, converted)
