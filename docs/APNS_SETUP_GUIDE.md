# Claude Watch APNs Setup Guide

A comprehensive guide for configuring Apple Push Notification service (APNs) with Claude Watch's Cloudflare Worker.

## Overview

Apple Push Notification service (APNs) enables Claude Watch to instantly notify you on your Apple Watch when Claude Code needs approval for file edits, bash commands, or other tool usage. Without APNs, the watch app must continuously poll the server for new requests, which drains battery and introduces latency.

**Why APNs is Required:**
- **Instant Notifications**: Receive approval requests within 1-2 seconds
- **Battery Efficiency**: No constant polling from the watch
- **Wakes Watch Screen**: Notifications appear even when the watch is asleep
- **Actionable Alerts**: Approve/reject directly from the notification without opening the app

The Claude Watch Cloudflare Worker (located at `MCPServer/worker/src/index.js`) includes a complete APNs implementation that uses JWT authentication to send push notifications to paired Apple Watch devices.

---

## Prerequisites

Before configuring APNs, ensure you have:

- **Apple Developer Account** (paid membership required - $99/year)
  - Verify access: https://developer.apple.com/account
- **Cloudflare Account** with Workers access
  - Free tier is sufficient
- **Wrangler CLI** installed and authenticated
  ```bash
  npm install -g wrangler
  wrangler login
  ```
- **Claude Watch Cloudflare Worker** deployed
  - Located in `MCPServer/worker/`
  - Worker URL format: `https://<worker-name>.<your-subdomain>.workers.dev`

### Verify Prerequisites

```bash
# Check wrangler is installed
wrangler --version

# Verify you're logged in
wrangler whoami

# Verify worker is deployed
cd MCPServer/worker
wrangler deployments list
```

---

## Part 1: Apple Developer Portal Setup

### Step 1: Create an APNs Authentication Key

APNs uses token-based authentication with a `.p8` private key file. This is more secure and scalable than certificate-based authentication.

1. **Navigate to Keys Page**
   - Go to https://developer.apple.com/account/resources/authkeys/list
   - Sign in with your Apple Developer account

2. **Create New Key**
   - Click the **"+"** button (top-left, next to "Keys")
   - Enter key name: **"Claude Watch APNs"** (or any descriptive name)
   - Check the box for **"Apple Push Notifications service (APNs)"**
   - Click **"Continue"**

3. **Download the Key**
   - Click **"Register"** to create the key
   - Click **"Download"** to save the `.p8` file
   - **CRITICAL**: Save this file securely - it can only be downloaded ONCE
   - The file will be named: `AuthKey_XXXXXXXXXX.p8` (where X is your Key ID)

4. **Note Your Key ID**
   - The Key ID is shown on the keys list page (10 characters, alphanumeric)
   - Example: `AB12CD34EF`
   - You'll need this for Cloudflare configuration

5. **Find Your Team ID**
   - Navigate to https://developer.apple.com/account
   - Your Team ID is shown on the membership page or in the top-right corner
   - Example: `TEAM123456`
   - Alternatively, it's visible in the keys list page header

### Expected Results

After completing Step 1, you should have:
- ✅ `.p8` file downloaded (e.g., `AuthKey_AB12CD34EF.p8`)
- ✅ Key ID noted (10 characters)
- ✅ Team ID noted (10 characters)
- ✅ Key visible in https://developer.apple.com/account/resources/authkeys/list

---

## Part 2: Cloudflare Worker Secret Configuration

The Cloudflare Worker requires four environment variables to send APNs notifications:

| Variable | Description | Example |
|----------|-------------|---------|
| `APNS_KEY_ID` | The 10-character Key ID from Apple | `AB12CD34EF` |
| `APNS_TEAM_ID` | Your Apple Developer Team ID | `TEAM123456` |
| `APNS_PRIVATE_KEY` | Base64-encoded `.p8` file contents | `LS0tLS1CRUdJT...` |
| `APNS_BUNDLE_ID` | App bundle identifier (already set in `wrangler.toml`) | `com.edgeoftrust.claudewatch` |

### Step 2: Configure Secrets Using Wrangler

Navigate to your worker directory:

```bash
cd MCPServer/worker
```

#### Set APNS_KEY_ID

```bash
npx wrangler secret put APNS_KEY_ID
```

When prompted, enter your 10-character Key ID:
```
Enter a secret value: AB12CD34EF
```

#### Set APNS_TEAM_ID

```bash
npx wrangler secret put APNS_TEAM_ID
```

When prompted, enter your Team ID:
```
Enter a secret value: TEAM123456
```

#### Set APNS_PRIVATE_KEY

First, encode your `.p8` file to base64:

```bash
# macOS/Linux
base64 -i ~/Downloads/AuthKey_AB12CD34EF.p8 | pbcopy

# Linux (without pbcopy)
base64 -i ~/Downloads/AuthKey_AB12CD34EF.p8

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\Downloads\AuthKey_AB12CD34EF.p8")) | Set-Clipboard
```

Then set the secret (paste the base64 string when prompted):

```bash
npx wrangler secret put APNS_PRIVATE_KEY
```

Paste the base64-encoded key:
```
Enter a secret value: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JR0hBZ0VBTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSEJHMHdhd0lCQVFRZ...
```

### Step 3: Verify Secrets Are Set

List all secrets to confirm they're configured:

```bash
npx wrangler secret list
```

Expected output:
```
┌────────────────────┬─────────────────────┐
│ Name               │ Value               │
├────────────────────┼─────────────────────┤
│ APNS_KEY_ID        │ (encrypted)         │
│ APNS_TEAM_ID       │ (encrypted)         │
│ APNS_PRIVATE_KEY   │ (encrypted)         │
└────────────────────┴─────────────────────┘
```

You should see all three secrets listed. The actual values are encrypted and not displayed.

### Step 4: Verify APNS_BUNDLE_ID

Check that the bundle ID matches your app:

```bash
cat wrangler.toml | grep APNS_BUNDLE_ID
```

Expected output:
```toml
APNS_BUNDLE_ID = "com.edgeoftrust.claudewatch"
```

If this doesn't match your app's bundle ID (found in Xcode project settings), update it in `wrangler.toml`.

### Step 5: Deploy the Worker

Deploy with the updated secrets:

```bash
npx wrangler deploy
```

Expected output:
```
 ⛅️ wrangler 3.x.x
------------------
Total Upload: xx.xx KiB / gzip: xx.xx KiB
Uploaded claude-watch (x.xx sec)
Published claude-watch (x.xx sec)
  https://claude-watch.<your-subdomain>.workers.dev
Current Deployment ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Note your worker URL - you'll need it for testing.

---

## Part 3: Environment Configuration (Sandbox vs Production)

APNs has two environments with different endpoints:

| Environment | APNs Endpoint | Used For |
|-------------|---------------|----------|
| **Sandbox** | `api.sandbox.push.apple.com` | Xcode debug builds, development |
| **Production** | `api.push.apple.com` | TestFlight, App Store, release builds |

### Current Environment Setting

Check your current environment:

```bash
cat wrangler.toml | grep APNS_SANDBOX
```

Default configuration:
```toml
APNS_SANDBOX = "true"  # Use sandbox for dev builds
```

### When to Use Sandbox

Use sandbox APNs (`APNS_SANDBOX = "true"`) for:
- ✅ Development builds installed via Xcode
- ✅ Simulator testing (if APNs simulators are supported)
- ✅ Internal testing with debug builds

### When to Switch to Production

Switch to production APNs (`APNS_SANDBOX = "false"`) for:
- ✅ **TestFlight builds** (CRITICAL - TestFlight uses production APNs)
- ✅ App Store distribution
- ✅ Ad Hoc distribution
- ✅ Enterprise distribution

### Switching Environments

**To switch to production** (required for TestFlight):

1. Edit `wrangler.toml`:
   ```toml
   APNS_SANDBOX = "false"
   ```

2. Deploy the change:
   ```bash
   npx wrangler deploy
   ```

**To switch back to sandbox** (for development):

1. Edit `wrangler.toml`:
   ```toml
   APNS_SANDBOX = "true"
   ```

2. Deploy the change:
   ```bash
   npx wrangler deploy
   ```

**Important Notes:**
- Device tokens from sandbox and production environments are **different**
- Users must **re-pair** when switching between sandbox and production
- Keep separate pairing codes/IDs for development and production testing

---

## Part 4: Verification

### Step 6: Test APNs with a Physical Watch

APNs cannot be tested with simulators - you must use a physical Apple Watch.

#### A. Pair Your Watch

1. Build and install Claude Watch on your physical Apple Watch (via Xcode)
2. Open the Claude Watch app
3. Tap **"Pair with Claude Code"**
4. Generate a pairing code from your worker:

```bash
WORKER_URL="https://claude-watch.<your-subdomain>.workers.dev"

curl -X POST "$WORKER_URL/pair"
```

Expected response:
```json
{
  "code": "ABC-123",
  "pairingId": "550e8400-e29b-41d4-a716-446655440000",
  "expiresIn": 600
}
```

5. Enter the code on your watch
6. Wait for "Paired successfully" confirmation
7. **Save the `pairingId`** - you'll need it for testing

#### B. Send Test Notification

```bash
WORKER_URL="https://claude-watch.<your-subdomain>.workers.dev"
PAIRING_ID="your-pairing-id-from-step-6"

curl -X POST "$WORKER_URL/request" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"type\": \"bash\",
    \"title\": \"APNs Test Notification\",
    \"description\": \"Testing push notifications\",
    \"command\": \"echo 'Hello from APNs'\"
  }"
```

Expected response with APNs working:
```json
{
  "requestId": "abc123ef",
  "apnsSent": true
}
```

Expected response if APNs is NOT configured:
```json
{
  "requestId": "abc123ef",
  "apnsSent": false
}
```

#### C. Verify Notification on Watch

Within 1-2 seconds, you should see:
- ✅ Watch screen wakes (if asleep)
- ✅ Haptic feedback (gentle tap)
- ✅ Notification banner with title: **"Claude: bash"**
- ✅ Notification body: **"APNs Test Notification"**
- ✅ Action buttons: **"Approve"** and **"Reject"**

#### D. Test Approval Flow

1. Tap **"Approve"** on the notification
2. Verify the response with:

```bash
REQUEST_ID="abc123ef"  # Use the requestId from step B

curl "$WORKER_URL/request/$REQUEST_ID"
```

Expected response:
```json
{
  "id": "abc123ef",
  "status": "approved",
  "response": true,
  "respondedAt": 1705501234567
}
```

### Common Verification Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `apnsSent: false` | Secrets not configured | Re-check Step 2, verify secrets exist |
| No notification received | Wrong APNs environment | Verify `APNS_SANDBOX` matches your build type |
| `BadDeviceToken` error | Device token invalid/expired | Re-pair your watch to get a new token |
| `InvalidProviderToken` | Wrong Team ID or Key ID | Re-check Apple Developer Portal values |
| `Unregistered` error | Token from different environment | Switch `APNS_SANDBOX` setting |

---

## Troubleshooting

### Issue 1: Notifications Not Received

**Symptoms:**
- API returns `apnsSent: true`
- No notification appears on watch
- No errors in worker logs

**Possible Causes & Solutions:**

1. **Wrong APNs Environment**
   - Check your build type (Debug = sandbox, Release/TestFlight = production)
   - Verify `APNS_SANDBOX` in `wrangler.toml` matches your build
   - Solution: Edit `wrangler.toml` and redeploy

2. **Device Token Mismatch**
   - Device tokens differ between sandbox and production
   - Switching environments invalidates existing tokens
   - Solution: Re-pair your watch after switching environments

3. **Bundle ID Mismatch**
   - `APNS_BUNDLE_ID` must exactly match your app's bundle identifier
   - Check Xcode: Target > Signing & Capabilities > Bundle Identifier
   - Solution: Update `wrangler.toml` with correct bundle ID

4. **Notification Permissions Not Granted**
   - Watch app may not have notification permissions
   - Solution: Check Settings > Notifications > Claude Watch on paired iPhone

### Issue 2: `apnsSent: false` in Response

**Symptoms:**
- API returns `apnsSent: false`
- No notification is sent

**Possible Causes & Solutions:**

1. **Secrets Not Configured**
   ```bash
   # Check if secrets exist
   cd MCPServer/worker
   npx wrangler secret list
   ```
   - Solution: Ensure all 3 secrets are listed (APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY)

2. **Invalid Base64 Encoding**
   - Private key may be incorrectly encoded
   - Solution: Re-encode the `.p8` file and set the secret again:
   ```bash
   base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy
   npx wrangler secret put APNS_PRIVATE_KEY
   # Paste the base64 string
   ```

3. **Worker Not Redeployed**
   - Secrets only apply after deployment
   - Solution: `npx wrangler deploy`

### Issue 3: APNs Authentication Errors

**Common APNs Error Responses:**

| Error Reason | HTTP Status | Meaning | Solution |
|--------------|-------------|---------|----------|
| `BadDeviceToken` | 400 | Device token is invalid | Re-pair watch to get new token |
| `Unregistered` | 410 | Token no longer valid for app | Re-pair watch |
| `InvalidProviderToken` | 403 | JWT authentication failed | Verify Key ID, Team ID, and private key |
| `BadPath` | 404 | Device token format invalid | Check token is hex string (no spaces) |
| `TooManyRequests` | 429 | Rate limit exceeded | Implement backoff, reduce notification frequency |
| `TopicDisallowed` | 400 | Bundle ID mismatch | Verify `APNS_BUNDLE_ID` matches app |

**Debugging Authentication Errors:**

1. **Verify Key ID**
   ```bash
   # Check the Key ID on Apple Developer Portal
   # https://developer.apple.com/account/resources/authkeys/list
   # Compare with your secret value
   ```

2. **Verify Team ID**
   ```bash
   # Check your Team ID
   # https://developer.apple.com/account
   # Visible in Membership section or top-right corner
   ```

3. **Verify Private Key Format**
   ```bash
   # The .p8 file should start with:
   cat ~/Downloads/AuthKey_XXXXXXXXXX.p8
   # -----BEGIN PRIVATE KEY-----
   # MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg...
   # -----END PRIVATE KEY-----
   ```

### Issue 4: Worker Deployment Fails

**Symptoms:**
- `npx wrangler deploy` returns errors
- Secrets not updating

**Possible Causes & Solutions:**

1. **Not Authenticated**
   ```bash
   wrangler login
   ```

2. **Wrong Directory**
   ```bash
   cd MCPServer/worker
   # Ensure wrangler.toml exists in current directory
   ls wrangler.toml
   ```

3. **KV Namespace Issues**
   - The worker requires two KV namespaces: `PAIRINGS` and `REQUESTS`
   - These should be pre-configured in `wrangler.toml`
   - If missing, create them:
   ```bash
   npx wrangler kv:namespace create PAIRINGS
   npx wrangler kv:namespace create REQUESTS
   # Update wrangler.toml with the returned IDs
   ```

### Issue 5: Testing with Simulator

**Symptom:**
- Cannot test APNs with watchOS Simulator

**Cause:**
- Apple's APNs servers do not deliver notifications to simulators
- Only physical devices receive APNs notifications

**Solution:**
- Use a physical Apple Watch for APNs testing
- For development without physical device, the app falls back to polling mode

---

## Quick Reference

### Essential Commands

```bash
# Navigate to worker directory
cd MCPServer/worker

# Configure APNs secrets
npx wrangler secret put APNS_KEY_ID
npx wrangler secret put APNS_TEAM_ID
npx wrangler secret put APNS_PRIVATE_KEY

# List configured secrets
npx wrangler secret list

# Deploy worker
npx wrangler deploy

# View deployment logs
npx wrangler tail

# Generate pairing code
curl -X POST https://claude-watch.<your-subdomain>.workers.dev/pair

# Send test notification
curl -X POST https://claude-watch.<your-subdomain>.workers.dev/request \
  -H "Content-Type: application/json" \
  -d '{"pairingId":"YOUR_PAIRING_ID","type":"bash","title":"Test","description":"Testing APNs"}'

# Check request status
curl https://claude-watch.<your-subdomain>.workers.dev/request/REQUEST_ID
```

### Environment Variables

| Variable | Set Via | Example Value | Required |
|----------|---------|---------------|----------|
| `APNS_KEY_ID` | `wrangler secret` | `AB12CD34EF` | Yes |
| `APNS_TEAM_ID` | `wrangler secret` | `TEAM123456` | Yes |
| `APNS_PRIVATE_KEY` | `wrangler secret` | `LS0tLS1CR...` (base64) | Yes |
| `APNS_BUNDLE_ID` | `wrangler.toml` | `com.edgeoftrust.claudewatch` | Yes |
| `APNS_SANDBOX` | `wrangler.toml` | `"true"` or `"false"` | Yes |

### APNs Endpoints

| Environment | Endpoint | Port |
|-------------|----------|------|
| Sandbox | `api.sandbox.push.apple.com` | 443 |
| Production | `api.push.apple.com` | 443 |

### Build Types and APNs Environment

| Build Type | `APNS_SANDBOX` Setting | APNs Endpoint |
|------------|------------------------|---------------|
| Xcode Debug Build | `"true"` | Sandbox |
| Xcode Release Build | `"false"` | Production |
| TestFlight | `"false"` | Production |
| App Store | `"false"` | Production |
| Simulator | N/A | Not supported |

---

## Security Best Practices

### Key Management

1. **Never Commit Keys to Version Control**
   - The `.p8` file should NEVER be committed to Git
   - Keep it in a secure location (password manager, encrypted volume)
   - Add to `.gitignore`: `*.p8`

2. **Limit Key Permissions**
   - Create a dedicated APNs key for Claude Watch
   - Don't reuse keys across multiple apps
   - Only enable "Apple Push Notifications service (APNs)" permission

3. **Rotate Keys Periodically**
   - Apple allows up to 2 APNs keys per account
   - Create a new key, update secrets, test, then revoke old key
   - Recommended: Rotate every 12 months

### Secret Storage

1. **Use Wrangler Secrets, Not Environment Variables**
   - Secrets are encrypted at rest in Cloudflare
   - Not visible in `wrangler.toml` or deployment logs
   - Cannot be read via API

2. **Avoid Storing Secrets Locally**
   - Don't put secrets in shell scripts
   - Don't store in plaintext files
   - Use environment variables only for local testing (never committed)

3. **Verify Secret Access**
   ```bash
   # Only you (the authenticated Cloudflare user) can modify secrets
   npx wrangler secret list
   # Shows secret names, but NOT values
   ```

### Network Security

1. **Always Use HTTPS**
   - Worker automatically uses HTTPS
   - APNs requires TLS 1.2+ (enforced by Apple)

2. **Validate Device Tokens**
   - The worker validates tokens before sending notifications
   - Invalid tokens are rejected by APNs and should be cleared from storage

3. **Implement Rate Limiting** (Optional Enhancement)
   - Current implementation has no rate limits
   - Consider adding per-pairing rate limits to prevent abuse
   - Example: Max 10 notifications per minute per device

### Monitoring

1. **Check Worker Logs**
   ```bash
   npx wrangler tail
   ```
   - Monitor for APNs errors
   - Track notification delivery rates

2. **Monitor APNs Error Rates**
   - High `BadDeviceToken` rates indicate users need to re-pair
   - `InvalidProviderToken` indicates configuration issues

3. **Track Pairing Activity**
   - Review pairing codes and completion rates
   - Expired codes (not completed within 10 minutes) are automatically cleaned up

---

## Next Steps

After completing APNs setup:

1. ✅ **Enable the Claude Code Hook**
   - Follow the guide in `plans/feat-apns-and-hooks-setup.md`
   - Configure `.claude/hooks/watch-approval-cloud.py`
   - Set up pairing ID using `claude-watch-pair.py`

2. ✅ **Test End-to-End Flow**
   - Trigger a bash command in Claude Code
   - Receive notification on watch
   - Approve/reject from notification
   - Verify command executes or is blocked

3. ✅ **Prepare for TestFlight** (Optional)
   - Switch to production APNs (`APNS_SANDBOX = "false"`)
   - Create app icons (see `docs/plans/feat-testflight-beta-distribution.md`)
   - Upload build to App Store Connect

4. ✅ **Monitor and Iterate**
   - Check worker logs for errors
   - Gather feedback from beta testers
   - Adjust notification content/timing as needed

---

## Additional Resources

- **Apple APNs Documentation**: https://developer.apple.com/documentation/usernotifications
- **APNs Provider API**: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server
- **Token-Based Authentication**: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns
- **Cloudflare Workers**: https://developers.cloudflare.com/workers/
- **Wrangler CLI**: https://developers.cloudflare.com/workers/wrangler/
- **Claude Watch Repository**: Current repository

---

## Troubleshooting Resources

If you encounter issues not covered in this guide:

1. **Check Worker Logs**
   ```bash
   cd MCPServer/worker
   npx wrangler tail
   ```

2. **Review APNs Error Codes**
   - https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/handling_notification_responses_from_apns

3. **Verify Worker Health**
   ```bash
   curl https://claude-watch.<your-subdomain>.workers.dev/health
   ```

4. **Test Device Pairing**
   - Delete existing pairing (unpair from watch)
   - Generate new pairing code
   - Complete pairing flow
   - Test notification delivery

5. **Contact Support**
   - File an issue in the GitHub repository
   - Include: APNs error messages, worker logs, environment settings
   - Redact: Private keys, device tokens, pairing IDs

---

*Last Updated: 2026-01-17*
