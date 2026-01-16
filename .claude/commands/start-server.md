---
description: Start the MCP server for watch connectivity
allowed-tools: Bash(python:*), Bash(python3:*), Bash(source:*), Bash(pip:*), Read
---

# Start MCP Server

Start the Python MCP server for watch connectivity:

1. Check if virtual environment exists, create if needed
2. Install dependencies if missing
3. Start the server in standalone mode

```bash
cd MCPServer

# Create venv if needed
python3 -m venv venv 2>/dev/null || true

# Activate and install deps
source venv/bin/activate
pip install -r requirements.txt

# Start server
python server.py --standalone --port 8787
```

The server provides:
- WebSocket endpoint on port 8787
- REST API on port 8788
- MCP protocol support for Claude Code

Test endpoints:
- GET http://localhost:8788/state - Current state
- POST http://localhost:8788/action/respond - Approve/reject actions
