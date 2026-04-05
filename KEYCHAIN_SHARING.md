# Keychain Sharing Setup

## Problem
The App Clip shows "API keys required" even when keys are configured in the main GutSense app. This is because the keychain isn't being shared between the two targets.

## Solution
Enable Keychain Sharing using App Groups.

---

## Automatic Setup (Recommended)

### For Main App (GutSense):
1. Open Xcode
2. Select the **GutSense** target (main app)
3. Go to "Signing & Capabilities" tab
4. Click **"+ Capability"** button
5. Add **"Keychain Sharing"** capability
6. In the Keychain Groups list, add:
   ```
   group.com.headydiscy.isg
   ```
7. Xcode will automatically create the entitlements file

### For App Clip (StrongGutAppClip):
The App Clip entitlements already include the keychain access group, but verify:
1. Select the **StrongGutAppClip** target
2. Go to "Signing & Capabilities" tab  
3. Verify **"Keychain Sharing"** capability exists
4. If not, add it and ensure it has:
   ```
   group.com.headydiscy.isg
   ```

---

## What Was Changed

### Code Changes (Already Done):
✅ `KeychainService.swift`:
   - Added `keychainAccessGroup` property
   - Updated `save()` to use access group
   - Updated `read()` to use access group
   - Updated `delete()` to use access group
   - Uses conditional compilation for simulator (keychain groups don't work in simulator)

✅ `StrongGutAppClip.entitlements`:
   - Added `keychain-access-groups` array
   - Includes `$(AppIdentifierPrefix)com.headydiscy.isg`

### What You Need to Do:
1. Add "Keychain Sharing" capability to **main GutSense app**
2. Rebuild both targets
3. Test on a **real device** (keychain sharing doesn't work in simulator)

---

## Testing

### In Simulator (Current Limitation):
- ⚠️ Keychain sharing **does not work** in the simulator
- Both apps will have separate keychains
- This is an iOS simulator limitation, not a bug in our code

### On Real Device:
1. Install main **GutSense** app
2. Open it and configure API keys in Settings
3. Close the app
4. Launch **StrongGutAppClip** (via URL/QR code)
5. ✅ API keys should be available
6. ✅ No orange warning
7. ✅ Can analyze food immediately

---

## Verifying Setup

### Check Main App Entitlements:
After adding the capability, check that `GutSense.entitlements` exists with:
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.headydiscy.isg</string>
</array>
```

### Check App Clip Entitlements:
File: `StrongGutAppClip/StrongGutAppClip.entitlements` should have:
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.headydiscy.isg</string>
</array>
<key>com.apple.developer.parent-application-identifiers</key>
<array>
    <string>$(AppIdentifierPrefix)com.headydiscy.isg</string>
</array>
```

---

## How It Works

### Keychain Access Group:
- Main app saves to: `group.com.headydiscy.isg`
- App Clip reads from: `group.com.headydiscy.isg`
- Both share the same keychain space
- Requires proper entitlements on both targets

### Accessibility Level:
Changed from `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to `kSecAttrAccessibleAfterFirstUnlock` to allow both apps to access credentials.

---

## Alternative: Test Without Keychain Sharing

If you want to test the App Clip without configuring keys in the main app:

### Option 1: Hardcode Test Keys (Development Only)
In `StrongGutAppClipApp.swift`, add:
```swift
.onAppear {
    // REMOVE BEFORE PRODUCTION
    try? credentialsStore.saveCredential("your-test-key", for: "anthropic.api_key")
    try? credentialsStore.saveCredential("your-test-key", for: "gemini.api_key")
    credentialsStore.backendURL = "your-backend-url"
}
```

### Option 2: Add Settings Screen to App Clip
Create a simple settings sheet in the App Clip for API key entry. (Not recommended - defeats the purpose of quick access)

---

## Troubleshooting

### "API keys required" still showing on device:
1. Delete both apps from device
2. Clean build folder (⇧⌘K)
3. Rebuild and reinstall main app first
4. Configure API keys
5. Then install and test App Clip

### Keychain not syncing:
- Verify both targets have "Keychain Sharing" capability
- Verify both use the same access group ID
- Check signing: both must be signed with the same Team ID
- Try on a different device

### Works in main app, not in App Clip:
- Check App Clip's entitlements file exists and has correct groups
- Rebuild App Clip target
- Check provisioning profile includes keychain groups

---

## Production Checklist

Before submitting to App Store:

- [ ] Main app has "Keychain Sharing" capability
- [ ] App Clip has "Keychain Sharing" capability  
- [ ] Both use same keychain access group
- [ ] Tested on real device (not simulator)
- [ ] Verified keys persist across app launches
- [ ] Verified App Clip can read keys from main app
- [ ] Remove any hardcoded test keys
- [ ] Provisioning profiles include app groups

---

## Summary

**Problem**: App Clip can't access API keys from main app
**Root Cause**: Separate keychain storage by default
**Solution**: Enable Keychain Sharing capability with shared access group
**Limitation**: Testing requires real device (doesn't work in simulator)

Once configured, users who have the main GutSense app installed will have seamless access to the App Clip without re-entering credentials!
