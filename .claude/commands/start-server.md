---
description: Start the bridge server for watch connectivity
allowed-tools: Bash(python:*), Bash(python3:*), Bash(source:*), Bash(pip:*), Read
---

# Start Bridge Server

Start the Python bridge server for watch connectivity:

1. Check if virtual environment exists, create if needed
2. Install dependencies if missing
3. Start the bridge server

```bash
cd MCPServer

# Create venv if needed
python3 -m venv venv 2>/dev/null || true

# Activate and install deps
source venv/bin/activate
pip install -r requirements.txt

# Start bridge server (primary)
python -m bridge.main
```

The bridge provides:
- NDJSON WebSocket on port 8787 (for Claude CLI via --sdk-url)
- REST API on port 8788 (for watch via cloud relay)
- Cloud worker relay for remote watch access

Test endpoints:
- GET http://localhost:8788/state - Current session state
- GET http://localhost:8788/permissions - Pending permissions
- GET http://localhost:8788/progress - Task progress

Legacy standalone mode (if needed):
```bash
python server.py --standalone --port 8787
```
