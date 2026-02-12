"""
Integration tests for CLI Launcher — Workstream D, Task D5.

Tests the launcher at a higher level than the unit tests in test_launcher.py:
  D5.1  Bridge launch mode constructs correct CLI args
  D5.2  Session resume uses --resume flag
  D5.3  Kill bridge kills CLI process
  D5.4  Auto-registration on connect (real WebSocket)

D5.1-D5.3 use mocks (cannot spawn real `claude` binary in CI), but
exercise the Bridge-level integration rather than CLILauncher in isolation.

D5.4 uses the real e2e_bridge and mock_cli fixtures from conftest.py to
validate that a WebSocket connection triggers auto-registration with the
REST API.
"""
from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from MCPServer.bridge.launcher import CLILauncher
from MCPServer.bridge.main import Bridge

# Import e2e fixtures — pytest auto-discovers them from conftest.py.
from MCPServer.bridge.tests.conftest import E2EBridge, MockCLI


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_mock_process(pid: int = 55555) -> MagicMock:
    """Create a minimal mock asyncio.subprocess.Process for integration tests.

    Unlike the unit-test helper in test_launcher.py, this one is intentionally
    simpler — it exists only to satisfy the launch() call so we can inspect
    the *args* that were passed to ``create_subprocess_exec``.
    """
    proc = MagicMock()
    proc.pid = pid

    _exit_event = asyncio.Event()

    async def _wait():
        await _exit_event.wait()
        return 0

    def _on_terminate():
        _exit_event.set()

    def _on_kill():
        _exit_event.set()

    proc.wait = _wait
    proc.terminate = MagicMock(side_effect=_on_terminate)
    proc.kill = MagicMock(side_effect=_on_kill)

    # stderr readline — return empty immediately
    stderr_mock = AsyncMock()
    stderr_mock.readline = AsyncMock(return_value=b"")
    proc.stderr = stderr_mock

    return proc


# ---------------------------------------------------------------------------
# D5.1: Bridge launch mode constructs correct CLI args
# ---------------------------------------------------------------------------

class TestD5_1_BridgeLaunchArgs:
    """Verify that Bridge.start(launch=True) constructs correct CLI args."""

    @pytest.mark.asyncio
    async def test_launch_mode_constructs_correct_args(self) -> None:
        """Bridge launch mode must spawn claude with --sdk-url and standard flags."""
        bridge = Bridge(port=19800, pairing_id="launch-test")
        mock_proc = _make_mock_process()

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec, patch(
            "MCPServer.bridge.launcher.shutil.which",
            return_value="/usr/local/bin/claude",
        ):
            mock_exec.return_value = mock_proc

            await bridge.start(launch=True, cwd="/tmp/project", model="claude-sonnet-4-5-20250929")

            # Verify subprocess was called exactly once
            mock_exec.assert_called_once()
            args = list(mock_exec.call_args.args)

            # Binary
            assert args[0] == "/usr/local/bin/claude"

            # --sdk-url with correct port and a session UUID path
            assert "--sdk-url" in args
            sdk_url = args[args.index("--sdk-url") + 1]
            assert sdk_url.startswith("ws://localhost:19800/ws/cli/")
            # Session ID should be a UUID-like string
            session_id_part = sdk_url.split("/")[-1]
            assert len(session_id_part) > 8  # UUID is 36 chars

            # Standard flags
            assert "--print" in args
            assert "--output-format" in args
            assert args[args.index("--output-format") + 1] == "stream-json"
            assert "--input-format" in args
            assert args[args.index("--input-format") + 1] == "stream-json"
            assert "--verbose" in args

            # Trailing -p ""
            assert args[-2] == "-p"
            assert args[-1] == ""

            # cwd passed through
            assert mock_exec.call_args.kwargs.get("cwd") == "/tmp/project"

        await bridge.stop()

    @pytest.mark.asyncio
    async def test_launch_mode_includes_model_flag(self) -> None:
        """When model is specified, --model <model> must appear in args."""
        bridge = Bridge(port=19802, pairing_id="model-test")
        mock_proc = _make_mock_process()

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec, patch(
            "MCPServer.bridge.launcher.shutil.which",
            return_value="claude",
        ):
            mock_exec.return_value = mock_proc

            await bridge.start(launch=True, cwd="/tmp", model="claude-sonnet-4-5-20250929")

            args = list(mock_exec.call_args.args)
            assert "--model" in args
            assert args[args.index("--model") + 1] == "claude-sonnet-4-5-20250929"

        await bridge.stop()

    @pytest.mark.asyncio
    async def test_launch_mode_no_model_when_not_specified(self) -> None:
        """When no model is passed to bridge.start(), --model must not appear."""
        bridge = Bridge(port=19804, pairing_id="no-model-test")
        mock_proc = _make_mock_process()

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec, patch(
            "MCPServer.bridge.launcher.shutil.which",
            return_value="claude",
        ):
            mock_exec.return_value = mock_proc

            await bridge.start(launch=True, cwd="/tmp")

            args = list(mock_exec.call_args.args)
            assert "--model" not in args

        await bridge.stop()

    @pytest.mark.asyncio
    async def test_launch_mode_creates_launcher(self) -> None:
        """Bridge.start(launch=True) must create a CLILauncher on the bridge."""
        bridge = Bridge(port=19806, pairing_id="launcher-check")
        mock_proc = _make_mock_process()

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec, patch(
            "MCPServer.bridge.launcher.shutil.which",
            return_value="claude",
        ):
            mock_exec.return_value = mock_proc

            # Before start: no launcher
            assert bridge._launcher is None

            await bridge.start(launch=True, cwd="/tmp")

            # After start with launch=True: launcher exists
            assert bridge._launcher is not None
            assert isinstance(bridge._launcher, CLILauncher)
            assert bridge._launcher.port == 19806

        await bridge.stop()


# ---------------------------------------------------------------------------
# D5.2: Session resume uses --resume flag
# ---------------------------------------------------------------------------

class TestD5_2_SessionResume:
    """Verify that CLILauncher.relaunch() adds --resume <cli_session_id>."""

    @pytest.mark.asyncio
    async def test_resume_includes_flag(self) -> None:
        """After setting cli_session_id, relaunch must include --resume."""
        launcher = CLILauncher(port=19800)
        mock_proc_1 = _make_mock_process(pid=1001)
        mock_proc_2 = _make_mock_process(pid=1002)

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            # Set the CLI's internal session ID (as Bridge._handle_system would)
            launcher.set_cli_session_id(session_id, "prev-sess-123")

            # Relaunch
            result = await launcher.relaunch(session_id)
            assert result is True

            # Inspect the second spawn call
            relaunch_args = list(mock_exec.call_args_list[1].args)
            assert "--resume" in relaunch_args
            assert relaunch_args[relaunch_args.index("--resume") + 1] == "prev-sess-123"

    @pytest.mark.asyncio
    async def test_resume_preserves_sdk_url_session_id(self) -> None:
        """After relaunch, the --sdk-url must still use the SAME session_id."""
        launcher = CLILauncher(port=19800)
        mock_proc_1 = _make_mock_process(pid=2001)
        mock_proc_2 = _make_mock_process(pid=2002)

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id
            launcher.set_cli_session_id(session_id, "resume-sess-456")

            await launcher.relaunch(session_id)

            # Both calls must use the same session_id in --sdk-url
            for call in mock_exec.call_args_list:
                args = list(call.args)
                sdk_url = args[args.index("--sdk-url") + 1]
                assert session_id in sdk_url

    @pytest.mark.asyncio
    async def test_resume_updates_pid(self) -> None:
        """After relaunch, the session's PID must reflect the new process."""
        launcher = CLILauncher(port=19800)
        mock_proc_1 = _make_mock_process(pid=3001)
        mock_proc_2 = _make_mock_process(pid=3002)

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            assert info.pid == 3001

            launcher.set_cli_session_id(info.session_id, "sess-789")
            await launcher.relaunch(info.session_id)

            assert info.pid == 3002
            assert info.state == "starting"


# ---------------------------------------------------------------------------
# D5.3: Kill bridge kills CLI process
# ---------------------------------------------------------------------------

class TestD5_3_KillBridge:
    """Verify that killing the bridge terminates the launched CLI process."""

    @pytest.mark.asyncio
    async def test_kill_all_terminates_child(self) -> None:
        """CLILauncher.kill_all() must send SIGTERM to child process."""
        launcher = CLILauncher(port=19800)
        mock_proc = _make_mock_process(pid=4001)

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            assert launcher.is_alive(info.session_id) is True

            await launcher.kill_all()

            # SIGTERM should have been called
            mock_proc.terminate.assert_called_once()
            assert launcher.is_alive(info.session_id) is False

    @pytest.mark.asyncio
    async def test_kill_single_session(self) -> None:
        """CLILauncher.kill() terminates only the targeted session."""
        launcher = CLILauncher(port=19800)
        mock_proc_a = _make_mock_process(pid=5001)
        mock_proc_b = _make_mock_process(pid=5002)

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec:
            mock_exec.side_effect = [mock_proc_a, mock_proc_b]

            info_a = await launcher.launch(cwd="/tmp", claude_binary="claude")
            info_b = await launcher.launch(cwd="/tmp", claude_binary="claude")

            # Kill only session A
            result = await launcher.kill(info_a.session_id)
            assert result is True

            mock_proc_a.terminate.assert_called_once()
            mock_proc_b.terminate.assert_not_called()

            assert launcher.is_alive(info_a.session_id) is False
            assert launcher.is_alive(info_b.session_id) is True

    @pytest.mark.asyncio
    async def test_bridge_stop_kills_launcher(self) -> None:
        """Bridge.stop() must call kill_all on the launcher."""
        bridge = Bridge(port=19808, pairing_id="stop-test")
        mock_proc = _make_mock_process()

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec, patch(
            "MCPServer.bridge.launcher.shutil.which",
            return_value="claude",
        ):
            mock_exec.return_value = mock_proc

            await bridge.start(launch=True, cwd="/tmp")

            # The launcher should have a running session
            assert bridge._launcher is not None
            sessions = bridge._launcher.list_sessions()
            assert len(sessions) == 1

            await bridge.stop()

            # After stop, the process should have been terminated
            mock_proc.terminate.assert_called_once()

    @pytest.mark.asyncio
    async def test_kill_marks_session_exited(self) -> None:
        """After kill(), session state must be 'exited' with exit_code -1."""
        launcher = CLILauncher(port=19800)
        mock_proc = _make_mock_process(pid=6001)

        with patch(
            "MCPServer.bridge.launcher.asyncio.create_subprocess_exec",
            new_callable=AsyncMock,
        ) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            assert info.state == "starting"

            await launcher.kill(info.session_id)

            assert info.state == "exited"
            assert info.exit_code == -1


# ---------------------------------------------------------------------------
# D5.4: Auto-registration on connect (real WebSocket)
# ---------------------------------------------------------------------------

class TestD5_4_AutoRegistration:
    """Verify that connecting a CLI WebSocket auto-registers with the API.

    Uses real e2e_bridge and mock_cli fixtures from conftest.py.
    """

    @pytest.mark.asyncio
    async def test_cli_connect_registers_session(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI
    ) -> None:
        """A WebSocket connect must auto-register session with the REST API."""
        bridge = e2e_bridge.bridge
        pairing_id = e2e_bridge.pairing_id

        # The mock_cli fixture connects to /ws/cli/{session_id}.
        # After connection, the session should be auto-registered in the API.
        assert bridge._api is not None, "API should be active on e2e_bridge"
        assert pairing_id in bridge._api._pairing_to_session, (
            f"pairing_id {pairing_id} should be registered after CLI connect"
        )

        # The registered session_id should match the mock_cli's session_id
        registered_sid = bridge._api._pairing_to_session[pairing_id]
        assert registered_sid == mock_cli.session_id

    @pytest.mark.asyncio
    async def test_session_exists_in_bridge(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI
    ) -> None:
        """After connect, the session should appear in bridge._sessions."""
        bridge = e2e_bridge.bridge
        assert mock_cli.session_id in bridge.sessions

        session = bridge.sessions[mock_cli.session_id]
        assert session.cli_socket is not None

    @pytest.mark.asyncio
    async def test_multiple_connects_last_wins(self, e2e_bridge: E2EBridge) -> None:
        """If two CLIs connect with different session_ids, both get registered
        but the pairing maps to the last one (pairing_id is a 1:1 mapping)."""
        import uuid
        from websockets.asyncio.client import connect as ws_connect

        bridge = e2e_bridge.bridge
        pairing_id = e2e_bridge.pairing_id

        # Connect first client
        sid_1 = f"multi-sess-{uuid.uuid4().hex[:8]}"
        url_1 = f"{e2e_bridge.ws_base}/ws/cli/{sid_1}"
        ws_1 = await ws_connect(url_1)
        await asyncio.sleep(0.05)

        # pairing_id now maps to sid_1
        assert bridge._api._pairing_to_session[pairing_id] == sid_1

        # Connect second client
        sid_2 = f"multi-sess-{uuid.uuid4().hex[:8]}"
        url_2 = f"{e2e_bridge.ws_base}/ws/cli/{sid_2}"
        ws_2 = await ws_connect(url_2)
        await asyncio.sleep(0.05)

        # pairing_id now maps to sid_2 (last connect wins)
        assert bridge._api._pairing_to_session[pairing_id] == sid_2

        # Both sessions exist in bridge
        assert sid_1 in bridge.sessions
        assert sid_2 in bridge.sessions

        await ws_1.close()
        await ws_2.close()

    @pytest.mark.asyncio
    async def test_disconnect_preserves_registration(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI
    ) -> None:
        """After CLI disconnects, the pairing registration should remain
        (the watch may still be polling)."""
        bridge = e2e_bridge.bridge
        pairing_id = e2e_bridge.pairing_id

        # Verify registered
        assert pairing_id in bridge._api._pairing_to_session

        # Disconnect
        await mock_cli.disconnect()
        await asyncio.sleep(0.05)

        # Registration should still be there
        assert pairing_id in bridge._api._pairing_to_session
        assert bridge._api._pairing_to_session[pairing_id] == mock_cli.session_id
