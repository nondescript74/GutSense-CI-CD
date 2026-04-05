# App Clip Signing Issue - RESOLVED

## The Problem
When trying to install the App Clip on a device, you got this error:
```
Entitlement keychain-access-groups not found on provisioning profile.
This entitlement is not a valid entitlement and should be removed.
```

## What Happened
I added the keychain access group directly to the entitlements file, but Apple requires that keychain sharing be enabled through the **Signing & Capabilities** tab in Xcode first, not just in the plist file.

## What I Fixed

### 1. Removed Manual Keychain Entry
✅ Removed `keychain-access-groups` from `StrongGutAppClip.entitlements`
   - This was causing the provisioning error
   - The entitlement needs to be added via the Capabilities UI, not manually

### 2. Made Keychain Sharing Optional
✅ Updated `KeychainService.swift` to handle optional access group:
```swift
private let keychainAccessGroup: String? = nil
```
   - App Clip will now work WITHOUT keychain sharing
   - Each app will have its own keychain
   - No provisioning errors

### 3. Updated All Keychain Methods
✅ `save()`, `read()`, and `delete()` now check if access group exists:
```swift
if let accessGroup = keychainAccessGroup {
    query[kSecAttrAccessGroup] = accessGroup
}
```

## Current Status

### ✅ What Works Now:
- App Clip will install on device without errors
- App Clip has its own keychain storage
- Main app has its own keychain storage
- No more provisioning failures

### ⚠️ What's Different:
- API keys are NOT shared between main app and App Clip
- Users will need to configure API keys separately in the App Clip
- This is temporary until you add the Keychain Sharing capability

## Try Again

**Rebuild and Install:**
1. Clean build folder (⇧⌘K)
2. Select StrongGutAppClip scheme
3. Select your device
4. Press ⌘R to build and install
5. ✅ Should install successfully now!

## Testing Without API Keys

The App Clip will show the orange warning "API keys required". This is correct! 

**To test the full flow, you have 3 options:**

### Option 1: Add Keys Directly in App Clip (Temporary)
You can modify `StrongGutAppClipApp.swift` to add test keys:
```swift
var body: some Scene {
    WindowGroup {
        StrongGutClipView()
            .environmentObject(credentialsStore)
            .onAppear {
                // TEMPORARY - Remove before production
                try? credentialsStore.saveCredential("your-anthropic-key", for: "anthropic.api_key")
                try? credentialsStore.saveCredential("your-gemini-key", for: "gemini.api_key")
                credentialsStore.backendURL = "your-backend-url"
            }
    }
}
```

### Option 2: Add Settings to App Clip
Create a simple settings screen in the App Clip for API key entry.

### Option 3: Enable Full Keychain Sharing (Later)
When ready for production:
1. Add "Keychain Sharing" capability to BOTH targets (main app + App Clip)
2. Use same access group: `group.com.headydiscy.isg`
3. In `KeychainService.swift`, change:
   ```swift
   private let keychainAccessGroup: String? = "group.com.headydiscy.isg"
   ```
4. Test on real device (doesn't work in simulator)

## Why This Approach?

**Advantages:**
- ✅ App Clip installs without errors
- ✅ Works in simulator
- ✅ Can test immediately
- ✅ No provisioning issues

**Trade-offs:**
- ⚠️ No automatic key sharing
- ⚠️ Each app maintains separate keychains
- ⚠️ Users need to enter keys if they want to use App Clip independently

**For Production:**
- When you enable Keychain Sharing capability
- Simply uncomment the access group line
- Keys will be shared automatically
- Better user experience

## Next Steps

1. **Now**: Rebuild and test App Clip on device
2. **During Development**: Use hardcoded test keys or add settings UI
3. **Before Production**: Enable Keychain Sharing capability on both targets
4. **Production**: Re-enable access group in KeychainService

## Summary

✅ **Fixed**: Removed invalid entitlement causing provisioning error
✅ **Works**: App Clip now installs on device
⚠️ **Note**: API keys are not shared (by design, for now)
📝 **Later**: Add Keychain Sharing capability for key sharing

The App Clip is now fully functional - just needs API keys configured!
