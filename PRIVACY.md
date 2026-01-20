# Privacy Policy for Claude Watch

**Last Updated: January 20, 2026**

## Overview

Claude Watch is a watchOS application that provides a wearable interface for approving Claude Code actions. This privacy policy explains how we handle your data.

## Data Collection

Claude Watch does **not** collect, store, or transmit any personal data to external servers.

### Local Data Only

- All communication occurs between your Apple Watch and your local development machine
- No data is sent to third-party services
- No analytics or tracking is implemented
- No user accounts or registration required

### Network Communication

The app communicates via:
- **WebSocket**: Direct connection to your local MCP server
- **Push Notifications**: Apple Push Notification service (APNs) for alerts

Push notification tokens are used solely for delivering approval requests from your own development machine.

## Data Storage

- Pairing codes are stored locally on device using secure storage
- Session data is temporary and cleared when the app closes
- No data is persisted to cloud services

## Third-Party Services

Claude Watch uses:
- **Apple Push Notification service (APNs)**: For delivering notifications
- No other third-party services are used

## Your Rights

Since we don't collect personal data, there is no data to access, modify, or delete.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted to this page.

## Contact

For questions about this privacy policy, please open an issue at:
https://github.com/dfotesco/claude-watch/issues
