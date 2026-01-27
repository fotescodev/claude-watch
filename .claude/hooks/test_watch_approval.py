#!/usr/bin/env python3
"""
Tests for watch-approval-cloud.py

Run with: python test_watch_approval.py
"""
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock

# Add the hooks directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import the module under test
import importlib.util
spec = importlib.util.spec_from_file_location(
    "watch_approval",
    os.path.join(os.path.dirname(__file__), "watch-approval-cloud.py")
)
watch_approval = importlib.util.module_from_spec(spec)


class TestGetPairingId(unittest.TestCase):
    """Test pairing ID loading from various sources."""

    def setUp(self):
        # Reload module to reset state
        spec.loader.exec_module(watch_approval)
        # Clear environment
        if "CLAUDE_WATCH_PAIRING_ID" in os.environ:
            del os.environ["CLAUDE_WATCH_PAIRING_ID"]

    def test_env_variable_priority(self):
        """Environment variable should take priority over config file."""
        os.environ["CLAUDE_WATCH_PAIRING_ID"] = "env-pairing-id-123"

        # Even with a config file, env var should win
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            f.write("file-pairing-id-456")
            temp_path = f.name

        try:
            with patch.object(watch_approval, 'PAIRING_CONFIG_FILE', temp_path):
                result = watch_approval.get_pairing_id()
                self.assertEqual(result, "env-pairing-id-123")
        finally:
            os.unlink(temp_path)
            del os.environ["CLAUDE_WATCH_PAIRING_ID"]

    def test_config_file_fallback(self):
        """Config file should be used when env var not set."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            f.write("file-pairing-id-789\n")  # With trailing newline
            temp_path = f.name

        try:
            with patch.object(watch_approval, 'PAIRING_CONFIG_FILE', temp_path):
                result = watch_approval.get_pairing_id()
                self.assertEqual(result, "file-pairing-id-789")
        finally:
            os.unlink(temp_path)

    def test_none_when_not_configured(self):
        """Should return None when neither env var nor file exists."""
        with patch.object(watch_approval, 'PAIRING_CONFIG_FILE', '/nonexistent/path'):
            result = watch_approval.get_pairing_id()
            self.assertIsNone(result)

    def test_empty_env_var_falls_through(self):
        """Empty env var should fall through to config file."""
        os.environ["CLAUDE_WATCH_PAIRING_ID"] = "   "  # Whitespace only

        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            f.write("file-pairing-id-abc")
            temp_path = f.name

        try:
            with patch.object(watch_approval, 'PAIRING_CONFIG_FILE', temp_path):
                result = watch_approval.get_pairing_id()
                self.assertEqual(result, "file-pairing-id-abc")
        finally:
            os.unlink(temp_path)
            del os.environ["CLAUDE_WATCH_PAIRING_ID"]

    def test_empty_config_file_returns_none(self):
        """Empty config file should return None."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            f.write("")  # Empty file
            temp_path = f.name

        try:
            with patch.object(watch_approval, 'PAIRING_CONFIG_FILE', temp_path):
                result = watch_approval.get_pairing_id()
                self.assertIsNone(result)
        finally:
            os.unlink(temp_path)


class TestMapToolType(unittest.TestCase):
    """Test tool type mapping."""

    def setUp(self):
        spec.loader.exec_module(watch_approval)

    def test_bash_mapping(self):
        self.assertEqual(watch_approval.map_tool_type("Bash"), "bash")

    def test_edit_mapping(self):
        self.assertEqual(watch_approval.map_tool_type("Edit"), "file_edit")

    def test_write_mapping(self):
        self.assertEqual(watch_approval.map_tool_type("Write"), "file_create")

    def test_multi_edit_mapping(self):
        self.assertEqual(watch_approval.map_tool_type("MultiEdit"), "file_edit")

    def test_unknown_tool(self):
        self.assertEqual(watch_approval.map_tool_type("Unknown"), "tool_use")


class TestBuildTitle(unittest.TestCase):
    """Test title building for different tool types."""

    def setUp(self):
        spec.loader.exec_module(watch_approval)

    def test_bash_title(self):
        tool_input = {"command": "npm install express"}
        result = watch_approval.build_title("Bash", tool_input)
        self.assertEqual(result, "Run: npm install express")

    def test_bash_long_command_truncated(self):
        tool_input = {"command": "a" * 100}
        result = watch_approval.build_title("Bash", tool_input)
        self.assertTrue(len(result) <= 50)  # "Run: " + 40 chars max

    def test_edit_title(self):
        tool_input = {"file_path": "/home/user/project/src/main.py"}
        result = watch_approval.build_title("Edit", tool_input)
        self.assertEqual(result, "Edit: main.py")

    def test_write_title(self):
        tool_input = {"file_path": "/tmp/newfile.txt"}
        result = watch_approval.build_title("Write", tool_input)
        self.assertEqual(result, "Create: newfile.txt")


class TestBuildDescription(unittest.TestCase):
    """Test description building."""

    def setUp(self):
        spec.loader.exec_module(watch_approval)

    def test_bash_description(self):
        tool_input = {"command": "echo hello"}
        result = watch_approval.build_description("Bash", tool_input)
        self.assertEqual(result, "echo hello")

    def test_edit_description_with_changes(self):
        tool_input = {"old_string": "foo", "new_string": "bar"}
        result = watch_approval.build_description("Edit", tool_input)
        self.assertEqual(result, "'foo' → 'bar'")

    def test_write_description(self):
        tool_input = {"content": "x" * 100}
        result = watch_approval.build_description("Write", tool_input)
        self.assertEqual(result, "Write 100 characters")


class TestToolsRequiringApproval(unittest.TestCase):
    """Test that the correct tools require approval."""

    def setUp(self):
        spec.loader.exec_module(watch_approval)

    def test_expected_tools(self):
        expected = {"Bash", "Edit", "Write", "MultiEdit", "NotebookEdit", "mobile_install_app", "mobile_uninstall_app"}
        self.assertEqual(watch_approval.TOOLS_REQUIRING_APPROVAL, expected)

    def test_read_not_included(self):
        self.assertNotIn("Read", watch_approval.TOOLS_REQUIRING_APPROVAL)

    def test_glob_not_included(self):
        self.assertNotIn("Glob", watch_approval.TOOLS_REQUIRING_APPROVAL)


class TestMainBehavior(unittest.TestCase):
    """Test main() function behavior."""

    def setUp(self):
        spec.loader.exec_module(watch_approval)

    def test_skips_non_approval_tools(self):
        """Tools not in TOOLS_REQUIRING_APPROVAL should exit 0 immediately."""
        # Mock stdin with a Read tool call
        mock_input = json.dumps({
            "tool_name": "Read",
            "tool_input": {"file_path": "/some/file"}
        })

        with patch('sys.stdin', MagicMock(read=lambda: mock_input)):
            with patch.object(watch_approval.json, 'load', return_value=json.loads(mock_input)):
                with self.assertRaises(SystemExit) as cm:
                    watch_approval.main()
                self.assertEqual(cm.exception.code, 0)

    def test_exits_gracefully_when_not_configured(self):
        """Should exit 0 (allow) when pairing is not configured."""
        mock_input = {
            "tool_name": "Bash",
            "tool_input": {"command": "echo test"}
        }

        with patch.object(watch_approval, 'get_pairing_id', return_value=None):
            with patch.object(watch_approval.json, 'load', return_value=mock_input):
                with self.assertRaises(SystemExit) as cm:
                    watch_approval.main()
                # Should exit 0 (fail open) when not configured
                self.assertEqual(cm.exception.code, 0)


if __name__ == "__main__":
    # Run tests
    print("=" * 60)
    print("Testing watch-approval-cloud.py")
    print("=" * 60)
    print()

    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    suite.addTests(loader.loadTestsFromTestCase(TestGetPairingId))
    suite.addTests(loader.loadTestsFromTestCase(TestMapToolType))
    suite.addTests(loader.loadTestsFromTestCase(TestBuildTitle))
    suite.addTests(loader.loadTestsFromTestCase(TestBuildDescription))
    suite.addTests(loader.loadTestsFromTestCase(TestToolsRequiringApproval))
    suite.addTests(loader.loadTestsFromTestCase(TestMainBehavior))

    # Run with verbosity
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Exit with appropriate code
    sys.exit(0 if result.wasSuccessful() else 1)
