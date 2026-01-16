# Claude Watch Simulator Testing Guide

A comprehensive guide for setting up and troubleshooting watchOS simulator testing for Claude Watch.

## Prerequisites

Before starting simulator testing, ensure you have:

- **Xcode Command Line Tools** installed: `xcode-select --install`
- **watchOS SDK** available (included with Xcode)
- **Apple Watch simulator** available in Xcode
- **Claude Watch app** built and ready for installation
- **Cloud server** running and accessible (for cloud mode testing)
- **Valid pairing ID** from cloud server for simulator device registration

### Verify Prerequisites

```bash
# Check Xcode tools
xcode-select -p

# List available simulators
xcrun simctl list devices

# Verify watchOS simulators are available
xcrun simctl list devices | grep "Apple Watch"
```

---

## Setup Steps

### Step 1: Boot the watchOS Simulator

Boot the Apple Watch Series 11 (46mm) simulator:

```bash
xcrun simctl boot "Apple Watch Series 11 (46mm)"
```

Verify the simulator is running:

```bash
xcrun simctl list devices | grep "Apple Watch"
```

You should see the simulator listed with status `(Booted)`.

### Step 2: Get the Simulator Device ID

Extract the device UUID for use in subsequent commands:

```bash
# List all devices with details
xcrun simctl list devices

# Extract just the Apple Watch device ID (look for the UUID in parentheses)
DEVICE_ID=$(xcrun simctl list devices | grep "Apple Watch Series 11" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)
echo $DEVICE_ID
```

### Step 3: Install the Claude Watch App

Build the app and obtain the app bundle path (typically in your Xcode build folder):

```bash
# Assuming your app path is available
APP_PATH="path/to/your/CloudWatch.app"
DEVICE_NAME="Apple Watch Series 11 (46mm)"

# Install the app
xcrun simctl install "$DEVICE_NAME" "$APP_PATH"
```

Verify the app is installed:

```bash
xcrun simctl listapps "$DEVICE_NAME" | grep -i claude
```

### Step 4: Configure App for Cloud Mode

Cloud mode allows the simulator to connect to your cloud server instead of trying to use localhost WebSocket connections (which simulators cannot reach).

#### Set Cloud Mode Enabled

```bash
DEVICE_ID="YOUR_DEVICE_UUID_HERE"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" useCloudMode -bool true
```

#### Register Pairing ID

Obtain a pairing ID from your cloud server, then configure it:

```bash
DEVICE_ID="YOUR_DEVICE_UUID_HERE"
BUNDLE_ID="com.edgeoftrust.claudewatch"
PAIRING_ID="your-pairing-id-from-server"

xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" pairingId -string "$PAIRING_ID"
```

#### Verify Configuration

```bash
DEVICE_ID="YOUR_DEVICE_UUID_HERE"
BUNDLE_ID="com.edgeoftrust.claudewatch"

# Check cloud mode setting
xcrun simctl spawn "$DEVICE_ID" defaults read "$BUNDLE_ID" useCloudMode

# Check pairing ID setting
xcrun simctl spawn "$DEVICE_ID" defaults read "$BUNDLE_ID" pairingId
```

Expected output:
```
useCloudMode: 1
pairingId: your-pairing-id-from-server
```

### Step 5: Establish Pairing with Cloud Server

Ensure your cloud server is running and accessible. The pairing ID should correspond to an active device registration on the server.

```bash
# Example: If using a local server on a different machine
# Verify network connectivity to your server
ping -c 1 your-server-address
```

### Step 6: Launch the App

Launch Claude Watch on the simulator:

```bash
DEVICE_NAME="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"
```

### Step 7: Verify App is Running

Check app status and view logs:

```bash
DEVICE_NAME="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

# List running apps
xcrun simctl listapps "$DEVICE_NAME" | grep -i claude

# View system logs (simulator must be running)
log stream --predicate 'process == "CloudWatch"' --level debug
```

---

## Troubleshooting

### Issue 1: Simulator Can't Connect to Localhost WebSocket

**Symptom:** App fails to connect with WebSocket connection errors

**Cause:** watchOS simulators have network sandbox restrictions and cannot connect to localhost on the host machine

**Solutions:**

1. **Use Cloud Mode (Recommended)**
   - Ensure `useCloudMode=true` is set
   - Verify `pairingId` is configured
   - Restart the app after configuration changes

2. **Use Bridge Server**
   - Set up a separate bridge service that the simulator can reach
   - Configure the app to connect to the bridge server instead of localhost

3. **Network Configuration**
   - Verify your cloud server is accessible from the simulator's network
   - Check firewall rules allow simulator traffic

```bash
# Verify cloud mode is enabled
DEVICE_ID="YOUR_DEVICE_UUID"
BUNDLE_ID="com.edgeoftrust.claudewatch"
xcrun simctl spawn "$DEVICE_ID" defaults read "$BUNDLE_ID" useCloudMode
```

### Issue 2: Notifications Not Appearing

**Symptom:** Notification tests fail; no notifications visible in simulator

**Causes:**
- Bundle ID mismatch
- App not installed or properly registered
- Notification permissions not granted

**Solutions:**

1. **Verify Bundle ID**
   ```bash
   DEVICE_NAME="Apple Watch Series 11 (46mm)"
   xcrun simctl listapps "$DEVICE_NAME"
   ```
   Ensure the bundle ID in your notification payload matches exactly.

2. **Reinstall App**
   ```bash
   DEVICE_NAME="Apple Watch Series 11 (46mm)"
   BUNDLE_ID="com.edgeoftrust.claudewatch"

   # Uninstall
   xcrun simctl uninstall "$DEVICE_NAME" "$BUNDLE_ID"

   # Reinstall
   xcrun simctl install "$DEVICE_NAME" "$APP_PATH"
   ```

3. **Check Notification Permissions**
   ```bash
   # Launch app to trigger permission prompt
   xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"

   # Grant notification permission in simulator UI or via Xcode
   ```

4. **Send Test Notification**
   ```bash
   DEVICE_NAME="Apple Watch Series 11 (46mm)"
   BUNDLE_ID="com.edgeoftrust.claudewatch"

   # Create payload.json with proper format
   cat > /tmp/notification_payload.json << 'EOF'
   {
     "aps": {
       "alert": "Test Notification",
       "badge": 1
     }
   }
   EOF

   # Send notification
   xcrun simctl push "$DEVICE_NAME" "$BUNDLE_ID" /tmp/notification_payload.json
   ```

### Issue 3: App Not Polling or Updating

**Symptom:** App doesn't fetch updates; appears disconnected

**Causes:**
- Cloud mode not enabled
- Pairing ID not configured or incorrect
- App not restarted after configuration changes
- Cloud server not responding

**Solutions:**

1. **Verify Cloud Configuration**
   ```bash
   DEVICE_ID="YOUR_DEVICE_UUID"
   BUNDLE_ID="com.edgeoftrust.claudewatch"

   # Check both settings
   xcrun simctl spawn "$DEVICE_ID" defaults read "$BUNDLE_ID" useCloudMode
   xcrun simctl spawn "$DEVICE_ID" defaults read "$BUNDLE_ID" pairingId
   ```

2. **Restart the App**
   ```bash
   DEVICE_NAME="Apple Watch Series 11 (46mm)"
   BUNDLE_ID="com.edgeoftrust.claudewatch"

   # Terminate
   xcrun simctl terminate "$DEVICE_NAME" "$BUNDLE_ID"

   # Wait a moment
   sleep 2

   # Relaunch
   xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"
   ```

3. **Verify Server Connectivity**
   ```bash
   # Check if cloud server is running
   curl -v https://your-server-address/health

   # Check server logs for pairing ID registration
   ```

4. **Check App Logs**
   ```bash
   # View simulator app logs
   log stream --predicate 'process == "CloudWatch"' --level debug --device-id="YOUR_DEVICE_UUID"
   ```

### Issue 4: Simulator Won't Boot

**Symptom:** `xcrun simctl boot` command hangs or fails

**Causes:**
- Xcode not installed or outdated
- Simulator already running
- System resources low

**Solutions:**

```bash
# Kill all simulators
xcrun simctl shutdown all

# Wait for system cleanup
sleep 3

# Try booting again
xcrun simctl boot "Apple Watch Series 11 (46mm)"

# Or use open command if available
open -a Simulator
```

### Issue 5: App Crashes on Launch

**Symptom:** App immediately crashes; appears in simulator but doesn't stay running

**Causes:**
- Invalid configuration (wrong pairing ID format)
- Missing required frameworks
- Debug symbols not loaded

**Solutions:**

1. **Check System Logs**
   ```bash
   log stream --predicate 'process == "CloudWatch"' --level debug
   ```

2. **Reset App Defaults**
   ```bash
   DEVICE_ID="YOUR_DEVICE_UUID"
   BUNDLE_ID="com.edgeoftrust.claudewatch"

   # Delete all app preferences
   xcrun simctl spawn "$DEVICE_ID" defaults delete "$BUNDLE_ID"

   # Reconfigure from scratch
   xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" useCloudMode -bool true
   xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" pairingId -string "YOUR_PAIRING_ID"
   ```

3. **Reinstall App**
   ```bash
   DEVICE_NAME="Apple Watch Series 11 (46mm)"
   BUNDLE_ID="com.edgeoftrust.claudewatch"

   xcrun simctl uninstall "$DEVICE_NAME" "$BUNDLE_ID"
   xcrun simctl install "$DEVICE_NAME" "$APP_PATH"
   ```

---

## Quick Reference Commands

### Device Management

```bash
# List all simulators
xcrun simctl list devices

# Boot simulator
xcrun simctl boot "Apple Watch Series 11 (46mm)"

# Shutdown simulator
xcrun simctl shutdown "Apple Watch Series 11 (46mm)"

# Shutdown all simulators
xcrun simctl shutdown all

# Get device UUID
xcrun simctl list devices | grep "Apple Watch Series 11" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1
```

### App Installation & Management

```bash
# Install app
xcrun simctl install "Apple Watch Series 11 (46mm)" path/to/CloudWatch.app

# Uninstall app
xcrun simctl uninstall "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch

# List installed apps
xcrun simctl listapps "Apple Watch Series 11 (46mm)"

# Launch app
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch

# Terminate app
xcrun simctl terminate "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch
```

### Configuration Management

```bash
# Set defaults (example: enable cloud mode)
xcrun simctl spawn DEVICE_UUID defaults write com.edgeoftrust.claudewatch useCloudMode -bool true

# Set string value (example: pairing ID)
xcrun simctl spawn DEVICE_UUID defaults write com.edgeoftrust.claudewatch pairingId -string "your-pairing-id"

# Read defaults
xcrun simctl spawn DEVICE_UUID defaults read com.edgeoftrust.claudewatch

# Delete all defaults for app
xcrun simctl spawn DEVICE_UUID defaults delete com.edgeoftrust.claudewatch
```

### Notifications & Testing

```bash
# Send notification to app
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch payload.json

# Create sample payload
cat > payload.json << 'EOF'
{
  "aps": {
    "alert": "Test Message",
    "badge": 1,
    "sound": "default"
  }
}
EOF
```

### Logging & Debugging

```bash
# Stream logs for CloudWatch app
log stream --predicate 'process == "CloudWatch"' --level debug

# Stream logs for specific simulator
log stream --predicate 'process == "CloudWatch"' --device-id=DEVICE_UUID --level debug

# View system log file
log show --last 1h --process CloudWatch

# Capture console output
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch 2>&1
```

---

## Complete Setup Script

Use this script to automate the entire setup process:

```bash
#!/bin/bash

# Configuration
DEVICE_NAME="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"
APP_PATH="path/to/your/CloudWatch.app"
PAIRING_ID="your-pairing-id-from-server"
SERVER_URL="https://your-server-address"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Claude Watch Simulator Setup${NC}"

# Step 1: Boot simulator
echo -e "${YELLOW}Step 1: Booting simulator...${NC}"
xcrun simctl boot "$DEVICE_NAME"
sleep 5

# Step 2: Get device UUID
echo -e "${YELLOW}Step 2: Getting device UUID...${NC}"
DEVICE_UUID=$(xcrun simctl list devices | grep "Apple Watch Series 11" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)
if [ -z "$DEVICE_UUID" ]; then
    echo -e "${RED}Failed to get device UUID${NC}"
    exit 1
fi
echo -e "${GREEN}Device UUID: $DEVICE_UUID${NC}"

# Step 3: Install app
echo -e "${YELLOW}Step 3: Installing app...${NC}"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}App path not found: $APP_PATH${NC}"
    exit 1
fi
xcrun simctl install "$DEVICE_NAME" "$APP_PATH"
sleep 2

# Step 4: Configure cloud mode
echo -e "${YELLOW}Step 4: Configuring cloud mode...${NC}"
xcrun simctl spawn "$DEVICE_UUID" defaults write "$BUNDLE_ID" useCloudMode -bool true
xcrun simctl spawn "$DEVICE_UUID" defaults write "$BUNDLE_ID" pairingId -string "$PAIRING_ID"
sleep 2

# Step 5: Verify configuration
echo -e "${YELLOW}Step 5: Verifying configuration...${NC}"
CLOUD_MODE=$(xcrun simctl spawn "$DEVICE_UUID" defaults read "$BUNDLE_ID" useCloudMode)
CONFIG_PAIRING=$(xcrun simctl spawn "$DEVICE_UUID" defaults read "$BUNDLE_ID" pairingId)
echo -e "${GREEN}Cloud Mode: $CLOUD_MODE${NC}"
echo -e "${GREEN}Pairing ID: $CONFIG_PAIRING${NC}"

# Step 6: Launch app
echo -e "${YELLOW}Step 6: Launching app...${NC}"
xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"
sleep 3

echo -e "${GREEN}Setup complete! Claude Watch is running on the simulator.${NC}"
echo -e "${GREEN}Device UUID: $DEVICE_UUID${NC}"
echo -e "${GREEN}Bundle ID: $BUNDLE_ID${NC}"
echo -e "${YELLOW}Check the simulator window for the app${NC}"
```

---

## Best Practices

1. **Always Use Cloud Mode for Simulators**
   - Simulators cannot reach localhost
   - Cloud mode is the only reliable connection method for watch simulators

2. **Restart App After Configuration Changes**
   - Always terminate and relaunch the app after changing defaults
   - Configuration changes don't take effect until the app is relaunched

3. **Keep Device UUID Handy**
   - Export as a shell variable for easier command execution
   - `export DEVICE_UUID=$(xcrun simctl list devices | grep "Apple Watch Series 11" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)`

4. **Monitor Logs During Testing**
   - Keep a log stream running in a separate terminal
   - Helps identify issues quickly: `log stream --predicate 'process == "CloudWatch"' --level debug`

5. **Test Network Connectivity**
   - Verify cloud server is accessible before testing app
   - Use health check endpoints to validate server availability

6. **Clean Up Between Test Sessions**
   - Shutdown simulators when not in use: `xcrun simctl shutdown all`
   - Free up system resources for faster development

---

## Additional Resources

- [Apple Simulator Documentation](https://developer.apple.com/documentation/xcode/running_your_app_in_the_simulator)
- [watchOS Development Guide](https://developer.apple.com/watchos/)
- [xcrun simctl Reference](https://developer.apple.com/library/archive/documentation/Utilities/Conceptual/MobileDeviceManagementProgrammingGuide/3-MDM_Protocol/MDM_Protocol.html)
- Claude Watch Project Documentation

---

## Support & Reporting Issues

When reporting simulator issues, include:
- Device UUID and simulator version
- Complete error logs (5-10 minutes of logs around the error time)
- Configuration values (useCloudMode, pairingId)
- Cloud server status and accessibility
- Steps to reproduce the issue

