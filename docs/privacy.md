# CC Watch Privacy Policy

**Last updated: January 21, 2026**

## Overview

CC Watch is a watchOS companion app for Claude Code that enables developers to approve code changes from their Apple Watch. We are committed to protecting your privacy and being transparent about our data practices.

## Information We Collect

CC Watch collects minimal information required for the app to function:

| Data Type | Purpose | Storage |
|-----------|---------|---------|
| **Device Identifier** | Delivering push notifications | Cloudflare Worker (encrypted) |
| **Push Token** | Apple Push Notification service | Cloudflare Worker (encrypted) |
| **Pairing Code** | Temporary code to link watch with computer | Deleted after pairing |

## End-to-End Encryption

**Your code is never visible to our servers.**

All session content (code, commands, approval requests) is encrypted end-to-end using industry-standard cryptography:

- **Key Exchange**: Curve25519 (X25519)
- **Encryption**: XSalsa20-Poly1305 (CLI) / ChaChaPoly (Watch)
- **Zero-Knowledge**: Our servers only forward encrypted blobs they cannot decrypt

Only your paired devices (Mac and Apple Watch) have the decryption keys.

## Data Retention

| Data | Retention |
|------|-----------|
| Pairing data | Deleted when you unpair devices |
| Approval requests | Deleted within 24 hours |
| Session content | Never stored on our servers (encrypted) |
| Push tokens | Deleted when you unpair or uninstall |

## What We Don't Collect

- Your source code
- Your Claude Code session content
- Your location
- Analytics or usage tracking
- Advertising identifiers

## Third-Party Services

CC Watch uses the following third-party services:

- **Apple Push Notification service (APNs)**: For delivering notifications to your watch
- **Cloudflare Workers**: For secure relay between your Mac and watch

We do not share your data with any other third parties.

## Your Rights

You can:

- **Delete your data**: Unpair your devices to remove all stored data
- **Uninstall**: Removing the app deletes all local data
- **Contact us**: Open an issue for any privacy concerns

## Children's Privacy

CC Watch is not intended for use by children under 13. We do not knowingly collect data from children.

## Changes to This Policy

We may update this policy from time to time. Changes will be posted on this page with an updated revision date.

## Contact

For privacy questions or concerns, please open an issue on our GitHub repository:

[https://github.com/fotescodev/claude-watch/issues](https://github.com/fotescodev/claude-watch/issues)

---

*CC Watch is an independent project and is not affiliated with Anthropic.*
