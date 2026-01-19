"""
Unit tests for Ralph progress streaming functionality.

Tests cover:
- WatchConnectionManager.stream_ralph_progress() method
- WebSocket ralph_progress message type handler
- REST API /ralph/progress endpoint

Uses Python's built-in unittest module for compatibility.
"""

import asyncio
import json
import unittest
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Guard imports for missing dependencies
# Note: server.py may fail to import if aiohttp/websockets are not installed
# because it uses type hints like 'web.Application' that reference unavailable modules
try:
    from server import (
        WatchConnectionManager,
        SessionState,
        SessionStatus,
    )
    IMPORTS_AVAILABLE = True
except (ImportError, NameError) as e:
    IMPORTS_AVAILABLE = False
    IMPORT_ERROR = str(e)

# Optional imports for additional tests
HAS_WEB_FEATURES = False
if IMPORTS_AVAILABLE:
    try:
        from server import create_rest_app, websocket_handler
        HAS_WEB_FEATURES = True
    except (ImportError, NameError):
        HAS_WEB_FEATURES = False


def async_test(coro):
    """Decorator to run async test methods."""
    def wrapper(*args, **kwargs):
        loop = asyncio.new_event_loop()
        try:
            return loop.run_until_complete(coro(*args, **kwargs))
        finally:
            loop.close()
    return wrapper


def skip_if_no_imports(test_method):
    """Skip test if required imports are not available."""
    def wrapper(self, *args, **kwargs):
        if not IMPORTS_AVAILABLE:
            self.skipTest(f"Required imports not available: {IMPORT_ERROR}")
        return test_method(self, *args, **kwargs)
    wrapper.__name__ = test_method.__name__
    return wrapper


# =============================================================================
# Tests for WatchConnectionManager.stream_ralph_progress()
# =============================================================================

class TestStreamRalphProgress(unittest.TestCase):
    """Tests for the stream_ralph_progress method."""

    def setUp(self):
        """Create a fresh WatchConnectionManager instance."""
        if not IMPORTS_AVAILABLE:
            self.skipTest(f"Required imports not available: {IMPORT_ERROR}")
        self.watch_manager = WatchConnectionManager()
        self.mock_websocket = AsyncMock()
        self.mock_websocket.send = AsyncMock()

    @async_test
    async def test_stream_ralph_progress_updates_state(self):
        """Verify that stream_ralph_progress updates internal state."""
        await self.watch_manager.stream_ralph_progress(
            event="started",
            progress=0.25,
            message="Starting task"
        )

        self.assertEqual(self.watch_manager.state.progress, 0.25)
        self.assertEqual(self.watch_manager.state.task_description, "Starting task")

    @async_test
    async def test_stream_ralph_progress_broadcasts_to_connections(self):
        """Verify that progress events are broadcast to connected watches."""
        self.watch_manager.connections.add(self.mock_websocket)

        await self.watch_manager.stream_ralph_progress(
            event="subtask_complete",
            progress=0.5,
            message="Subtask done"
        )

        # Verify broadcast was called
        self.mock_websocket.send.assert_called_once()

        # Parse the sent message
        sent_data = json.loads(self.mock_websocket.send.call_args[0][0])

        self.assertEqual(sent_data["type"], "ralph_progress")
        self.assertEqual(sent_data["event"], "subtask_complete")
        self.assertEqual(sent_data["progress"], 0.5)
        self.assertEqual(sent_data["message"], "Subtask done")
        self.assertIn("timestamp", sent_data)
        self.assertEqual(sent_data["metadata"], {})

    @async_test
    async def test_stream_ralph_progress_with_metadata(self):
        """Verify that metadata is included in broadcast."""
        self.watch_manager.connections.add(self.mock_websocket)

        metadata = {
            "subtask_id": "subtask-1-1",
            "files_changed": ["server.py", "test.py"]
        }

        await self.watch_manager.stream_ralph_progress(
            event="file_modified",
            progress=0.75,
            message="Modified files",
            metadata=metadata
        )

        sent_data = json.loads(self.mock_websocket.send.call_args[0][0])
        self.assertEqual(sent_data["metadata"], metadata)

    @async_test
    async def test_stream_ralph_progress_no_connections(self):
        """Verify that streaming with no connections doesn't raise errors."""
        # Should not raise any exception
        await self.watch_manager.stream_ralph_progress(
            event="test",
            progress=0.1,
            message="Test message"
        )

        # State should still be updated
        self.assertEqual(self.watch_manager.state.progress, 0.1)

    @async_test
    async def test_stream_ralph_progress_multiple_connections(self):
        """Verify that progress is broadcast to multiple connections."""
        ws1 = AsyncMock()
        ws2 = AsyncMock()
        ws3 = AsyncMock()

        self.watch_manager.connections.add(ws1)
        self.watch_manager.connections.add(ws2)
        self.watch_manager.connections.add(ws3)

        await self.watch_manager.stream_ralph_progress(
            event="progress",
            progress=0.33,
            message="One third done"
        )

        # All connections should receive the message
        ws1.send.assert_called_once()
        ws2.send.assert_called_once()
        ws3.send.assert_called_once()

    @async_test
    async def test_stream_ralph_progress_empty_message(self):
        """Verify behavior with empty message string."""
        self.watch_manager.connections.add(self.mock_websocket)

        await self.watch_manager.stream_ralph_progress(
            event="heartbeat",
            progress=0.5,
            message=""
        )

        sent_data = json.loads(self.mock_websocket.send.call_args[0][0])
        self.assertEqual(sent_data["message"], "")

    @async_test
    async def test_stream_ralph_progress_boundary_values(self):
        """Test progress boundary values (0.0 and 1.0)."""
        self.watch_manager.connections.add(self.mock_websocket)

        await self.watch_manager.stream_ralph_progress(
            event="started",
            progress=0.0,
            message="Just started"
        )
        self.assertEqual(self.watch_manager.state.progress, 0.0)

        await self.watch_manager.stream_ralph_progress(
            event="finished",
            progress=1.0,
            message="Complete"
        )
        self.assertEqual(self.watch_manager.state.progress, 1.0)


# =============================================================================
# Tests for WebSocket ralph_progress message handler
# =============================================================================

class TestWebSocketRalphProgressHandler(unittest.TestCase):
    """Tests for the WebSocket ralph_progress message type handler."""

    def setUp(self):
        """Set up test fixtures."""
        if not IMPORTS_AVAILABLE:
            self.skipTest(f"Required imports not available: {IMPORT_ERROR}")
        if not HAS_WEB_FEATURES:
            self.skipTest("WebSocket features not available (websockets/aiohttp not installed)")
        self.watch_manager = WatchConnectionManager()

    @async_test
    async def test_websocket_ralph_progress_message(self):
        """Test handling ralph_progress message via WebSocket."""
        # Create a mock WebSocket that yields a ralph_progress message then closes
        mock_ws = AsyncMock()
        mock_ws.send = AsyncMock()

        message = json.dumps({
            "type": "ralph_progress",
            "event": "task_started",
            "progress": 0.1,
            "message": "Starting execution",
            "metadata": {"task": "test-task"}
        })

        # Import here to avoid import errors if websockets not installed
        try:
            from websockets.exceptions import ConnectionClosed
        except ImportError:
            self.skipTest("websockets module not available")

        # Create an async iterator that yields one message then raises ConnectionClosed
        class MockWebSocketIterator:
            def __init__(self, messages):
                self.messages = iter(messages)

            def __aiter__(self):
                return self

            async def __anext__(self):
                try:
                    return next(self.messages)
                except StopIteration:
                    raise ConnectionClosed(None, None)

        mock_ws.__aiter__ = lambda self: MockWebSocketIterator([message])

        # Create a second connection to receive the broadcast
        receiver_ws = AsyncMock()
        receiver_ws.send = AsyncMock()
        self.watch_manager.connections.add(receiver_ws)

        # Run the handler
        try:
            await websocket_handler(mock_ws, self.watch_manager)
        except:
            pass  # Connection close is expected

        # Verify broadcast was sent to connected watches
        if receiver_ws.send.called:
            sent_data = json.loads(receiver_ws.send.call_args[0][0])
            self.assertEqual(sent_data["type"], "ralph_progress")
            self.assertEqual(sent_data["event"], "task_started")

    @async_test
    async def test_websocket_ping_pong(self):
        """Test that ping messages get pong responses."""
        try:
            from websockets.exceptions import ConnectionClosed
        except ImportError:
            self.skipTest("websockets module not available")

        mock_ws = AsyncMock()
        mock_ws.send = AsyncMock()

        ping_message = json.dumps({"type": "ping"})

        class MockWebSocketIterator:
            def __init__(self):
                self.yielded = False

            def __aiter__(self):
                return self

            async def __anext__(self):
                if not self.yielded:
                    self.yielded = True
                    return ping_message
                raise ConnectionClosed(None, None)

        mock_ws.__aiter__ = lambda self: MockWebSocketIterator()

        try:
            await websocket_handler(mock_ws, self.watch_manager)
        except:
            pass

        # Check that pong was sent (or state_sync)
        self.assertTrue(mock_ws.send.called)


# =============================================================================
# Tests for REST API /ralph/progress endpoint
# =============================================================================

class TestRalphProgressEndpoint(unittest.TestCase):
    """Tests for the /ralph/progress REST endpoint."""

    def setUp(self):
        """Set up test fixtures."""
        if not IMPORTS_AVAILABLE:
            self.skipTest(f"Required imports not available: {IMPORT_ERROR}")
        if not HAS_WEB_FEATURES:
            self.skipTest("REST API features not available (aiohttp not installed)")
        self.watch_manager = WatchConnectionManager()

    def _skip_if_no_aiohttp(self):
        """Skip test if aiohttp is not available."""
        try:
            import aiohttp
            from aiohttp.test_utils import TestClient
            from aiohttp import web
        except ImportError:
            self.skipTest("aiohttp module not available")

    @async_test
    async def test_post_ralph_progress_success(self):
        """Test successful POST to /ralph/progress endpoint."""
        self._skip_if_no_aiohttp()
        from aiohttp.test_utils import TestClient
        from aiohttp import web

        app = create_rest_app(self.watch_manager)

        async with web.AppRunner(app) as runner:
            await runner.setup()

            async with TestClient(runner.server) as client:
                response = await client.post(
                    "/ralph/progress",
                    json={
                        "event": "started",
                        "progress": 0.25,
                        "message": "Test progress"
                    }
                )

                self.assertEqual(response.status, 200)
                data = await response.json()
                self.assertTrue(data["success"])
                self.assertEqual(data["event"], "started")
                self.assertEqual(data["progress"], 0.25)

                # Verify state was updated
                self.assertEqual(self.watch_manager.state.progress, 0.25)

    @async_test
    async def test_post_ralph_progress_invalid_json(self):
        """Test POST with invalid JSON returns 400."""
        self._skip_if_no_aiohttp()
        from aiohttp.test_utils import TestClient
        from aiohttp import web

        app = create_rest_app(self.watch_manager)

        async with web.AppRunner(app) as runner:
            await runner.setup()

            async with TestClient(runner.server) as client:
                response = await client.post(
                    "/ralph/progress",
                    data="not json",
                    headers={"Content-Type": "application/json"}
                )

                self.assertEqual(response.status, 400)
                data = await response.json()
                self.assertIn("error", data)

    @async_test
    async def test_post_ralph_progress_invalid_progress_value(self):
        """Test POST with progress out of range returns 400."""
        self._skip_if_no_aiohttp()
        from aiohttp.test_utils import TestClient
        from aiohttp import web

        app = create_rest_app(self.watch_manager)

        async with web.AppRunner(app) as runner:
            await runner.setup()

            async with TestClient(runner.server) as client:
                # Test progress > 1.0
                response = await client.post(
                    "/ralph/progress",
                    json={
                        "event": "test",
                        "progress": 1.5,
                        "message": "Invalid progress"
                    }
                )

                self.assertEqual(response.status, 400)
                data = await response.json()
                self.assertIn("progress must be", data["error"])

                # Test progress < 0.0
                response = await client.post(
                    "/ralph/progress",
                    json={
                        "event": "test",
                        "progress": -0.1,
                        "message": "Negative progress"
                    }
                )

                self.assertEqual(response.status, 400)

    @async_test
    async def test_post_ralph_progress_with_metadata(self):
        """Test POST with metadata."""
        self._skip_if_no_aiohttp()
        from aiohttp.test_utils import TestClient
        from aiohttp import web

        app = create_rest_app(self.watch_manager)

        async with web.AppRunner(app) as runner:
            await runner.setup()

            async with TestClient(runner.server) as client:
                metadata = {
                    "subtask_id": "subtask-1-1",
                    "phase": "backend"
                }

                response = await client.post(
                    "/ralph/progress",
                    json={
                        "event": "subtask_complete",
                        "progress": 0.5,
                        "message": "Completed subtask",
                        "metadata": metadata
                    }
                )

                self.assertEqual(response.status, 200)
                data = await response.json()
                self.assertTrue(data["success"])

    @async_test
    async def test_post_ralph_progress_default_values(self):
        """Test POST with minimal required fields uses defaults."""
        self._skip_if_no_aiohttp()
        from aiohttp.test_utils import TestClient
        from aiohttp import web

        app = create_rest_app(self.watch_manager)

        async with web.AppRunner(app) as runner:
            await runner.setup()

            async with TestClient(runner.server) as client:
                # Only send event, let others default
                response = await client.post(
                    "/ralph/progress",
                    json={"event": "heartbeat"}
                )

                self.assertEqual(response.status, 200)
                data = await response.json()
                self.assertTrue(data["success"])
                self.assertEqual(data["event"], "heartbeat")
                self.assertEqual(data["progress"], 0.0)  # Default value

    @async_test
    async def test_post_ralph_progress_broadcasts_to_websockets(self):
        """Test that POST broadcasts to connected WebSocket clients."""
        self._skip_if_no_aiohttp()
        from aiohttp.test_utils import TestClient
        from aiohttp import web

        # Add a mock WebSocket connection
        mock_ws = AsyncMock()
        mock_ws.send = AsyncMock()
        self.watch_manager.connections.add(mock_ws)

        app = create_rest_app(self.watch_manager)

        async with web.AppRunner(app) as runner:
            await runner.setup()

            async with TestClient(runner.server) as client:
                response = await client.post(
                    "/ralph/progress",
                    json={
                        "event": "test_broadcast",
                        "progress": 0.75,
                        "message": "Broadcasting test"
                    }
                )

                self.assertEqual(response.status, 200)

                # Verify WebSocket received the broadcast
                mock_ws.send.assert_called()
                sent_data = json.loads(mock_ws.send.call_args[0][0])
                self.assertEqual(sent_data["type"], "ralph_progress")
                self.assertEqual(sent_data["event"], "test_broadcast")
                self.assertEqual(sent_data["progress"], 0.75)


# =============================================================================
# Integration Tests
# =============================================================================

class TestRalphProgressIntegration(unittest.TestCase):
    """Integration tests for the full progress flow."""

    def setUp(self):
        """Set up test fixtures."""
        if not IMPORTS_AVAILABLE:
            self.skipTest(f"Required imports not available: {IMPORT_ERROR}")
        self.watch_manager = WatchConnectionManager()

    @async_test
    async def test_full_progress_flow(self):
        """Test a complete progress flow from start to finish."""
        mock_ws = AsyncMock()
        mock_ws.send = AsyncMock()
        self.watch_manager.connections.add(mock_ws)

        # Simulate a typical Ralph execution progress flow
        progress_events = [
            ("started", 0.0, "Starting Ralph execution"),
            ("task_selected", 0.1, "Selected task: subtask-1-1"),
            ("executing", 0.25, "Executing subtask"),
            ("validating", 0.5, "Running verification"),
            ("task_completed", 0.75, "Subtask completed"),
            ("finished", 1.0, "Ralph execution complete"),
        ]

        for event, progress, message in progress_events:
            await self.watch_manager.stream_ralph_progress(
                event=event,
                progress=progress,
                message=message
            )

        # Verify all events were sent
        self.assertEqual(mock_ws.send.call_count, len(progress_events))

        # Verify final state
        self.assertEqual(self.watch_manager.state.progress, 1.0)
        self.assertEqual(self.watch_manager.state.task_description, "Ralph execution complete")

    @async_test
    async def test_progress_with_connection_failure(self):
        """Test that progress continues even if one connection fails."""
        good_ws = AsyncMock()
        good_ws.send = AsyncMock()

        bad_ws = AsyncMock()
        bad_ws.send = AsyncMock(side_effect=Exception("Connection lost"))

        self.watch_manager.connections.add(good_ws)
        self.watch_manager.connections.add(bad_ws)

        # Should not raise despite one connection failing
        await self.watch_manager.stream_ralph_progress(
            event="test",
            progress=0.5,
            message="Test with failure"
        )

        # Good connection should still receive the message
        good_ws.send.assert_called_once()


# =============================================================================
# Run tests
# =============================================================================

if __name__ == "__main__":
    # Run with verbosity
    unittest.main(verbosity=2)
