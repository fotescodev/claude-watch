"""
Tests for MCPServer.bridge.launcher — CLI launcher for Claude Code with --sdk-url.

Tests follow the spec naming from sdk-url-agent-execution-spec.md task A6:
  A6.1  launch() constructs correct command args
  A6.2  launch() with model and permission_mode adds correct flags
  A6.3  relaunch() with cli_session_id adds --resume flag
  A6.4  relaunch() without cli_session_id skips --resume flag
  A6.5  kill() sends SIGTERM then SIGKILL on timeout
  A6.6  mark_connected() updates state
  A6.7  set_cli_session_id() stores the ID
  A6.8  Process exit immediately after --resume clears cli_session_id

All tests mock asyncio.create_subprocess_exec since we cannot spawn
a real `claude` binary in tests.
"""
from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from MCPServer.bridge.launcher import CLILauncher, CLISessionInfo


# ---------------------------------------------------------------------------
# Helpers — mock subprocess
# ---------------------------------------------------------------------------

def _make_mock_process(
    pid: int = 12345,
    exit_code: int = 0,
    refuse_terminate: bool = False,
    auto_exit: bool = False,
) -> MagicMock:
    """Create a mock asyncio.subprocess.Process.

    Uses an asyncio.Event so that wait() blocks until the process is
    explicitly terminated or killed — just like a real subprocess.

    Args:
        pid: The fake PID to return.
        exit_code: The exit code that wait() will eventually return.
        refuse_terminate: If True, terminate() does NOT cause wait() to
                          return.  Only kill() does.  Simulates a process
                          that ignores SIGTERM.
        auto_exit: If True, wait() returns immediately without blocking.
                   Use for tests that need the process to exit on its own
                   (e.g., testing the immediate-exit-after-resume logic).
    """
    proc = MagicMock()
    proc.pid = pid

    _exit_event = asyncio.Event()

    if auto_exit:
        _exit_event.set()  # already "exited"

    async def _wait():
        await _exit_event.wait()
        return exit_code

    def _on_terminate():
        if not refuse_terminate:
            _exit_event.set()

    def _on_kill():
        _exit_event.set()

    proc.wait = _wait
    proc.terminate = MagicMock(side_effect=_on_terminate)
    proc.kill = MagicMock(side_effect=_on_kill)

    # stderr readline — return empty immediately (no output)
    stderr_mock = AsyncMock()
    stderr_mock.readline = AsyncMock(return_value=b"")
    proc.stderr = stderr_mock

    return proc


# ---------------------------------------------------------------------------
# TEST A6.1: launch() constructs correct command args
# ---------------------------------------------------------------------------

class TestLaunchArgs:
    @pytest.mark.asyncio
    async def test_constructs_correct_args(self) -> None:
        """launch() must pass --sdk-url, --print, --output-format, etc."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(
                cwd="/home/user/project",
                claude_binary="/usr/local/bin/claude",
            )

            # Verify subprocess was called
            mock_exec.assert_called_once()
            call_args = mock_exec.call_args

            # Extract positional args (the command + flags)
            args = list(call_args.args)

            assert args[0] == "/usr/local/bin/claude"
            assert "--sdk-url" in args
            sdk_url_idx = args.index("--sdk-url")
            sdk_url = args[sdk_url_idx + 1]
            assert sdk_url == f"ws://localhost:8787/ws/cli/{info.session_id}"

            assert "--print" in args
            assert "--output-format" in args
            assert args[args.index("--output-format") + 1] == "stream-json"
            assert "--input-format" in args
            assert args[args.index("--input-format") + 1] == "stream-json"
            assert "--verbose" in args

            # Ends with -p ""
            assert args[-2] == "-p"
            assert args[-1] == ""

            # cwd passed as keyword arg
            assert call_args.kwargs.get("cwd") == "/home/user/project"

    @pytest.mark.asyncio
    async def test_no_model_or_permission_flags_by_default(self) -> None:
        """Without model/permission_mode, those flags should not appear."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            await launcher.launch(
                cwd="/tmp",
                claude_binary="claude",
            )

            args = list(mock_exec.call_args.args)
            assert "--model" not in args
            assert "--permission-mode" not in args
            assert "--resume" not in args

    @pytest.mark.asyncio
    async def test_stores_pid_and_session(self) -> None:
        """launch() must store the PID and register the session."""
        launcher = CLILauncher(port=9000)
        mock_proc = _make_mock_process(pid=42)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")

            assert info.pid == 42
            assert info.state == "starting"
            assert info.session_id is not None
            assert launcher.get_session(info.session_id) is info

    @pytest.mark.asyncio
    async def test_uses_shutil_which_fallback(self) -> None:
        """When no claude_binary given and shutil.which finds it, use that."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec, \
             patch("MCPServer.bridge.launcher.shutil.which", return_value="/opt/bin/claude"):
            mock_exec.return_value = mock_proc

            await launcher.launch(cwd="/tmp")

            args = list(mock_exec.call_args.args)
            assert args[0] == "/opt/bin/claude"

    @pytest.mark.asyncio
    async def test_falls_back_to_bare_claude(self) -> None:
        """When no claude_binary given and shutil.which returns None, use 'claude'."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec, \
             patch("MCPServer.bridge.launcher.shutil.which", return_value=None):
            mock_exec.return_value = mock_proc

            await launcher.launch(cwd="/tmp")

            args = list(mock_exec.call_args.args)
            assert args[0] == "claude"


# ---------------------------------------------------------------------------
# TEST A6.2: launch() with model and permission_mode adds correct flags
# ---------------------------------------------------------------------------

class TestLaunchWithModelAndPermission:
    @pytest.mark.asyncio
    async def test_model_flag(self) -> None:
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(
                cwd="/tmp",
                model="claude-opus-4-6",
                claude_binary="claude",
            )

            args = list(mock_exec.call_args.args)
            assert "--model" in args
            assert args[args.index("--model") + 1] == "claude-opus-4-6"
            assert info.model == "claude-opus-4-6"

    @pytest.mark.asyncio
    async def test_permission_mode_flag(self) -> None:
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(
                cwd="/tmp",
                permission_mode="autoAccept",
                claude_binary="claude",
            )

            args = list(mock_exec.call_args.args)
            assert "--permission-mode" in args
            assert args[args.index("--permission-mode") + 1] == "autoAccept"
            assert info.permission_mode == "autoAccept"

    @pytest.mark.asyncio
    async def test_both_model_and_permission_mode(self) -> None:
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            await launcher.launch(
                cwd="/tmp",
                model="claude-sonnet-4-5-20250929",
                permission_mode="default",
                claude_binary="claude",
            )

            args = list(mock_exec.call_args.args)
            assert "--model" in args
            assert args[args.index("--model") + 1] == "claude-sonnet-4-5-20250929"
            assert "--permission-mode" in args
            assert args[args.index("--permission-mode") + 1] == "default"


# ---------------------------------------------------------------------------
# TEST A6.3: relaunch() with cli_session_id adds --resume flag
# ---------------------------------------------------------------------------

class TestRelaunchWithResume:
    @pytest.mark.asyncio
    async def test_resume_flag_present(self) -> None:
        """relaunch() should add --resume when cli_session_id is set."""
        launcher = CLILauncher(port=8787)
        mock_proc_1 = _make_mock_process(pid=100)
        mock_proc_2 = _make_mock_process(pid=200)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            # First call: initial launch; second call: relaunch
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            # Simulate receiving the CLI's internal session ID
            launcher.set_cli_session_id(session_id, "abc-123")

            result = await launcher.relaunch(session_id)

            assert result is True
            assert mock_exec.call_count == 2

            # The second call (relaunch) should include --resume
            relaunch_args = list(mock_exec.call_args_list[1].args)
            assert "--resume" in relaunch_args
            assert relaunch_args[relaunch_args.index("--resume") + 1] == "abc-123"

    @pytest.mark.asyncio
    async def test_relaunch_kills_old_process(self) -> None:
        """relaunch() must terminate the old process before spawning new one."""
        launcher = CLILauncher(port=8787)
        mock_proc_1 = _make_mock_process(pid=100)
        mock_proc_2 = _make_mock_process(pid=200)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            await launcher.relaunch(session_id)

            # Old process should have been terminated
            mock_proc_1.terminate.assert_called_once()

    @pytest.mark.asyncio
    async def test_relaunch_resets_state(self) -> None:
        """After relaunch, session state should be 'starting'."""
        launcher = CLILauncher(port=8787)
        mock_proc_1 = _make_mock_process(pid=100)
        mock_proc_2 = _make_mock_process(pid=200)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            await launcher.relaunch(session_id)

            updated_info = launcher.get_session(session_id)
            assert updated_info is not None
            assert updated_info.state == "starting"
            assert updated_info.pid == 200


# ---------------------------------------------------------------------------
# TEST A6.4: relaunch() without cli_session_id skips --resume flag
# ---------------------------------------------------------------------------

class TestRelaunchWithoutResume:
    @pytest.mark.asyncio
    async def test_no_resume_flag_when_no_cli_session_id(self) -> None:
        """relaunch() should NOT add --resume when cli_session_id is None."""
        launcher = CLILauncher(port=8787)
        mock_proc_1 = _make_mock_process(pid=100)
        mock_proc_2 = _make_mock_process(pid=200)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            # Do NOT set cli_session_id
            result = await launcher.relaunch(session_id)

            assert result is True
            assert mock_exec.call_count == 2

            # The second call (relaunch) should NOT include --resume
            relaunch_args = list(mock_exec.call_args_list[1].args)
            assert "--resume" not in relaunch_args

    @pytest.mark.asyncio
    async def test_relaunch_nonexistent_session(self) -> None:
        """relaunch() with unknown session_id should return False."""
        launcher = CLILauncher(port=8787)

        result = await launcher.relaunch("nonexistent-session-id")

        assert result is False


# ---------------------------------------------------------------------------
# TEST A6.5: kill() sends SIGTERM then SIGKILL on timeout
# ---------------------------------------------------------------------------

class TestKillProcess:
    @pytest.mark.asyncio
    async def test_graceful_kill_with_sigterm(self) -> None:
        """kill() sends SIGTERM and process exits within timeout."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process(pid=100, exit_code=0)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            result = await launcher.kill(session_id)

            assert result is True
            mock_proc.terminate.assert_called_once()
            # kill() should NOT have been called (process exited gracefully)
            mock_proc.kill.assert_not_called()

            # Session should be marked as exited
            updated_info = launcher.get_session(session_id)
            assert updated_info is not None
            assert updated_info.state == "exited"
            assert updated_info.exit_code == -1

    @pytest.mark.asyncio
    async def test_force_kill_after_timeout(self) -> None:
        """kill() sends SIGKILL when process ignores SIGTERM."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process(pid=100, refuse_terminate=True)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            result = await launcher.kill(session_id)

            assert result is True
            mock_proc.terminate.assert_called_once()
            mock_proc.kill.assert_called_once()  # SIGKILL after timeout

    @pytest.mark.asyncio
    async def test_kill_nonexistent_session(self) -> None:
        """kill() with unknown session_id should return False."""
        launcher = CLILauncher(port=8787)

        result = await launcher.kill("nonexistent-session-id")

        assert result is False

    @pytest.mark.asyncio
    async def test_is_not_alive_after_kill(self) -> None:
        """is_alive() should return False after kill()."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process(pid=100)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            assert launcher.is_alive(session_id) is True

            await launcher.kill(session_id)

            assert launcher.is_alive(session_id) is False


# ---------------------------------------------------------------------------
# TEST A6.6: mark_connected() updates state
# ---------------------------------------------------------------------------

class TestMarkConnected:
    @pytest.mark.asyncio
    async def test_updates_state_from_starting(self) -> None:
        """mark_connected() should update state from 'starting' to 'connected'."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            assert info.state == "starting"

            launcher.mark_connected(session_id)

            assert info.state == "connected"

    def test_no_change_for_exited_session(self) -> None:
        """mark_connected() should not change state if session is exited."""
        launcher = CLILauncher(port=8787)

        # Manually create a session in exited state
        info = CLISessionInfo(session_id="test-1", state="exited", cwd="/tmp")
        launcher._sessions["test-1"] = info

        launcher.mark_connected("test-1")

        # State should remain exited
        assert info.state == "exited"

    def test_no_error_for_unknown_session(self) -> None:
        """mark_connected() with unknown session_id should not crash."""
        launcher = CLILauncher(port=8787)

        # Should not raise
        launcher.mark_connected("nonexistent")


# ---------------------------------------------------------------------------
# TEST A6.7: set_cli_session_id() stores the ID
# ---------------------------------------------------------------------------

class TestSetCliSessionId:
    @pytest.mark.asyncio
    async def test_stores_cli_session_id(self) -> None:
        """set_cli_session_id() should store the CLI's internal session ID."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            assert info.cli_session_id is None

            launcher.set_cli_session_id(session_id, "cli-internal-abc-123")

            assert info.cli_session_id == "cli-internal-abc-123"

    def test_no_error_for_unknown_session(self) -> None:
        """set_cli_session_id() with unknown session_id should not crash."""
        launcher = CLILauncher(port=8787)

        # Should not raise
        launcher.set_cli_session_id("nonexistent", "some-cli-id")


# ---------------------------------------------------------------------------
# TEST A6.8: Process exit immediately after --resume clears cli_session_id
# ---------------------------------------------------------------------------

class TestImmediateExitClearsResume:
    @pytest.mark.asyncio
    async def test_clears_cli_session_id_on_immediate_exit(self) -> None:
        """If process exits within 5s after --resume, cli_session_id should be cleared."""
        launcher = CLILauncher(port=8787)

        # First process stays running; second exits immediately (simulating
        # quick exit after --resume).
        mock_proc_1 = _make_mock_process(pid=100)
        quick_exit_proc = _make_mock_process(pid=200, exit_code=1, auto_exit=True)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, quick_exit_proc]

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            # Simulate having a CLI session ID
            launcher.set_cli_session_id(session_id, "old-cli-session")
            assert info.cli_session_id == "old-cli-session"

            # Relaunch — will use --resume
            await launcher.relaunch(session_id)

            # The _monitor_exit task runs in the background. Give it a tick
            # to process the immediate exit.
            await asyncio.sleep(0.05)

            # cli_session_id should have been cleared because the process
            # exited immediately (< 5s) after --resume
            assert info.cli_session_id is None
            assert info.state == "exited"
            assert info.exit_code == 1

    @pytest.mark.asyncio
    async def test_preserves_cli_session_id_on_normal_exit(self) -> None:
        """If process exits after normal uptime (no --resume), cli_session_id should be preserved."""
        launcher = CLILauncher(port=8787)

        mock_proc = _make_mock_process(pid=100, exit_code=0, auto_exit=True)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.return_value = mock_proc

            info = await launcher.launch(cwd="/tmp", claude_binary="claude")
            session_id = info.session_id

            # Set a CLI session ID
            launcher.set_cli_session_id(session_id, "my-cli-session")

            # Let the monitor task run — this was a normal launch (no --resume)
            # so cli_session_id should NOT be cleared even on immediate exit
            await asyncio.sleep(0.05)

            assert info.cli_session_id == "my-cli-session"


# ---------------------------------------------------------------------------
# Additional edge-case tests
# ---------------------------------------------------------------------------

class TestListAndGetSessions:
    @pytest.mark.asyncio
    async def test_list_sessions(self) -> None:
        """list_sessions() returns all registered sessions."""
        launcher = CLILauncher(port=8787)
        mock_proc_1 = _make_mock_process(pid=1)
        mock_proc_2 = _make_mock_process(pid=2)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info1 = await launcher.launch(cwd="/tmp", claude_binary="claude")
            info2 = await launcher.launch(cwd="/tmp", claude_binary="claude")

            sessions = launcher.list_sessions()
            assert len(sessions) == 2
            session_ids = {s.session_id for s in sessions}
            assert info1.session_id in session_ids
            assert info2.session_id in session_ids

    def test_get_session_nonexistent(self) -> None:
        """get_session() returns None for unknown session_id."""
        launcher = CLILauncher(port=8787)

        assert launcher.get_session("nope") is None

    def test_is_alive_nonexistent(self) -> None:
        """is_alive() returns False for unknown session_id."""
        launcher = CLILauncher(port=8787)

        assert launcher.is_alive("nope") is False


class TestKillAll:
    @pytest.mark.asyncio
    async def test_kills_all_sessions(self) -> None:
        """kill_all() should terminate all running processes."""
        launcher = CLILauncher(port=8787)
        mock_proc_1 = _make_mock_process(pid=1)
        mock_proc_2 = _make_mock_process(pid=2)

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec:
            mock_exec.side_effect = [mock_proc_1, mock_proc_2]

            info1 = await launcher.launch(cwd="/tmp", claude_binary="claude")
            info2 = await launcher.launch(cwd="/tmp", claude_binary="claude")

            await launcher.kill_all()

            mock_proc_1.terminate.assert_called_once()
            mock_proc_2.terminate.assert_called_once()

            assert launcher.is_alive(info1.session_id) is False
            assert launcher.is_alive(info2.session_id) is False


class TestCwdDefault:
    @pytest.mark.asyncio
    async def test_uses_cwd_when_not_provided(self) -> None:
        """launch() should default to os.getcwd() when cwd is None."""
        launcher = CLILauncher(port=8787)
        mock_proc = _make_mock_process()

        with patch("MCPServer.bridge.launcher.asyncio.create_subprocess_exec", new_callable=AsyncMock) as mock_exec, \
             patch("MCPServer.bridge.launcher.os.getcwd", return_value="/default/cwd"):
            mock_exec.return_value = mock_proc

            info = await launcher.launch(claude_binary="claude")

            assert info.cwd == "/default/cwd"
            assert mock_exec.call_args.kwargs.get("cwd") == "/default/cwd"
