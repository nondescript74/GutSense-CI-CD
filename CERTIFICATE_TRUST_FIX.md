# Certificate and Trust Issues - Fix Guide

## Current Configuration
- **Team ID**: YKHW2TJ32G
- **Main App Bundle ID**: com.headydiscy.isg
- **App Clip Bundle ID**: com.headydiscy.isg.Clip
- **Signing**: Automatic

## Available Certificates
1. Apple Development: Zahirudeen Premji (595MZT93SV)
2. Apple Development: nondescript74@gmail.com (H6NK445278)

---

## Common Certificate & Trust Issues

### 1. Certificate Trust Problems

**Symptoms:**
- "The identity used to sign the executable is no longer valid"
- "Certificate has expired or is not yet valid"
- App won't install on device
- Trust warnings when pushing to TestFlight

**Solutions:**

#### A. Revoke and Regenerate Certificates
```bash
# 1. List current certificates
security find-identity -v -p codesigning

# 2. Delete old/expired certificates from keychain
# Open Keychain Access → My Certificates → Delete expired ones

# 3. Revoke in Apple Developer Portal
# https://developer.apple.com/account/resources/certificates/list
# Find old certificates and click Revoke

# 4. Let Xcode regenerate automatically
# Xcode → Preferences → Accounts → [Your Account] → Manage Certificates
# Click the + button → Apple Development
```

#### B. Clear Provisioning Profiles
```bash
# Remove all provisioning profiles
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*

# Xcode will regenerate them automatically on next build
```

#### C. Reset Signing Settings in Xcode
1. Select project in Xcode
2. For each target (GutSense, StrongGutAppClip, test targets):
   - Go to Signing & Capabilities
   - Uncheck "Automatically manage signing"
   - Wait a moment
   - Re-check "Automatically manage signing"
   - Ensure correct Team is selected (YKHW2TJ32G)

---

### 2. App Clip Specific Issues

**Important:** App Clips MUST have the same Team ID and certificate as the parent app.

#### Fix App Clip Signing
1. Ensure parent-application-identifiers is correct in `StrongGutAppClip.entitlements`:
```xml
<key>com.apple.developer.parent-application-identifiers</key>
<array>
    <string>$(AppIdentifierPrefix)com.headydiscy.isg</string>
</array>
```

2. Bundle ID must be a child of parent:
   - ✅ Parent: com.headydiscy.isg
   - ✅ App Clip: com.headydiscy.isg.Clip

3. App Clip must have **App Clip capability** enabled:
   - Select StrongGutAppClip target
   - Signing & Capabilities → + Capability → On Demand Install Capable

---

### 3. TestFlight/App Store Connect Issues

**Problem:** Trust issues when uploading to TestFlight

#### A. Use Distribution Certificate for Archives
```bash
# Check if you have a distribution certificate
security find-identity -v -p codesigning | grep "Distribution"

# If missing, create in Apple Developer Portal:
# Certificates → + → Apple Distribution
# Download and double-click to install
```

#### B. Ensure Correct Signing for Archive
1. Product → Archive (not just Build)
2. Before distributing, click "Validate App"
3. Choose "Automatically manage signing" or select the correct certificate

#### C. Clean and Rebuild
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# In Xcode
# Product → Clean Build Folder (Cmd+Shift+K)
# Product → Archive
```

---

### 4. Keychain Issues

#### Fix Locked Keychain
```bash
# Unlock login keychain
security unlock-keychain ~/Library/Keychains/login.keychain-db

# Set keychain to not lock automatically (optional)
security set-keychain-settings -t 3600 ~/Library/Keychains/login.keychain-db
```

#### Fix Certificate Trust in Keychain
1. Open Keychain Access
2. Find your Apple Development/Distribution certificate
3. Right-click → Get Info
4. Expand "Trust" section
5. Set "Code Signing" to "Always Trust"
6. Close and enter password

---

### 5. App Group Configuration (for App Clip data sharing)

If you need the App Clip to share data with the main app:

1. **Add App Groups capability to BOTH targets**:
   - Main app: Signing & Capabilities → + Capability → App Groups
   - App Clip: Signing & Capabilities → + Capability → App Groups

2. **Use the same group identifier**:
   - Format: `group.com.headydiscy.isg`

3. **Update entitlements files**:

**GutSense.entitlements**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.headydiscy.isg</string>
    </array>
</dict>
</plist>
```

**StrongGutAppClip.entitlements**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.parent-application-identifiers</key>
    <array>
        <string>$(AppIdentifierPrefix)com.headydiscy.isg</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.headydiscy.isg</string>
    </array>
</dict>
</plist>
```

---

### 6. Quick Fix Checklist

When you get trust issues, try these in order:

- [ ] Clean Build Folder (Cmd+Shift+K)
- [ ] Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
- [ ] Delete Provisioning Profiles: `rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*`
- [ ] Restart Xcode
- [ ] Toggle "Automatically manage signing" off and on
- [ ] Delete app from device/simulator and reinstall
- [ ] Check certificate validity in Keychain Access
- [ ] Revoke old certificates in Apple Developer Portal
- [ ] Let Xcode regenerate certificates
- [ ] Check that Team ID matches across all targets
- [ ] Verify bundle IDs are correct (App Clip must be child of parent)

---

### 7. Verify Current Configuration

```bash
# Check if certificates are valid
security find-identity -v -p codesigning

# Check provisioning profiles
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/

# Check bundle IDs in project
grep -E "PRODUCT_BUNDLE_IDENTIFIER" GutSense.xcodeproj/project.pbxproj | grep -v "/*"

# Verify team ID
grep "DEVELOPMENT_TEAM" GutSense.xcodeproj/project.pbxproj | head -5
```

---

### 8. If Nothing Works: Nuclear Option

```bash
# 1. Revoke ALL certificates in Apple Developer Portal
# https://developer.apple.com/account/resources/certificates/list

# 2. Delete ALL certificates from Keychain
# Keychain Access → Search "Apple" → Delete all development/distribution certs

# 3. Delete provisioning profiles
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*

# 4. Clean Xcode cache
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*

# 5. Restart Mac (optional but recommended)

# 6. In Xcode, for EACH target:
#    - Signing & Capabilities
#    - Uncheck "Automatically manage signing"
#    - Select Team: YKHW2TJ32G
#    - Re-check "Automatically manage signing"
#    - Xcode will generate everything fresh
```

---

## Common Error Messages

### "The executable was signed with invalid entitlements"
- **Fix**: Check that entitlements file exists and has correct format
- **App Clip specific**: Ensure parent-application-identifiers matches parent bundle ID

### "No signing certificate 'iOS Development' found"
- **Fix**: Generate new certificate in Xcode Preferences → Accounts → Manage Certificates

### "Provisioning profile doesn't match the entitlements"
- **Fix**: Delete provisioning profiles and let Xcode regenerate them

### "The identity used to sign the executable is no longer valid"
- **Fix**: Certificate expired or revoked. Regenerate in Apple Developer Portal

---

## Best Practices

1. **Use Automatic Signing**: Less prone to errors
2. **One certificate per machine**: Don't share certificates between computers
3. **Regular renewal**: Certificates expire after 1 year
4. **Keep Team ID consistent**: Across all targets and App Clips
5. **Test on device regularly**: Catches signing issues early
6. **Use Archive for TestFlight**: Never use Development builds for distribution

---

## Quick Reference

**Check Team ID**: Look for YKHW2TJ32G in all target settings
**Main App Bundle**: com.headydiscy.isg
**App Clip Bundle**: com.headydiscy.isg.Clip (must be child)
**Entitlements**: Check parent-application-identifiers in App Clip
**Certificates**: Keep only current ones in Keychain Access
**Clean often**: DerivedData and Provisioning Profiles
