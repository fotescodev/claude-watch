# Remmy Privacy Policy

**Last updated: February 25, 2026**

## Overview

Remmy is a watchOS app that lets you approve and control Claude Code sessions from your Apple Watch. Your privacy is important to us.

## Data Collection

Remmy does **not** collect, store, or share any personal data.

### What Remmy processes

- **Pairing codes**: Short-lived tokens used to link your watch to a Claude Code session. These expire within 5 minutes and are not stored permanently.
- **Action metadata**: When Claude Code requests approval, Remmy receives the action type (e.g., "edit file") and file name. This data is transient and not stored after the session ends.
- **Session state**: Connection status and session progress are held temporarily in memory during active sessions.

### What Remmy does NOT collect

- Source code or file contents
- Personal information (name, email, location)
- Usage analytics or telemetry
- Advertising identifiers
- Health or fitness data

## Cloud Relay

Remmy communicates through a secure cloud relay (`claude-watch.fotescodev.workers.dev`) using TLS 1.2+ encryption. The relay is stateless — it passes messages between your watch and CLI without logging or persisting any content. Session data expires automatically (approval queues within 1 hour, pairing codes within 5 minutes).

## On-Device Storage

Remmy stores only:
- Your pairing identifier (in the device Keychain)
- Your server URL preference (in UserDefaults)

No data is synced to iCloud or shared with third parties.

## Third-Party Services

Remmy does not integrate any third-party analytics, advertising, or tracking services.

## Children's Privacy

Remmy is not directed at children under 13 and does not knowingly collect data from children.

## Changes to This Policy

We may update this policy from time to time. Changes will be posted to this page with an updated date.

## Contact

If you have questions about this privacy policy, please open an issue at [github.com/fotescodev/claude-watch](https://github.com/fotescodev/claude-watch).
