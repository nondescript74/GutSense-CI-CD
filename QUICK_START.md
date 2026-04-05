# Quick Start - StrongGutAppClip Setup

## ⚡ Fast Track Setup (5 minutes)

Your App Clip is **almost ready**! Just need to share some files with the App Clip target.

### Step 1: Share Required Files (CRITICAL)

Open Xcode and for each file below, check the "StrongGutAppClip" target:

#### How to Add Target Membership:
1. Click on the file in Project Navigator (left sidebar)
2. Open File Inspector (⌥⌘1 or View → Inspectors → File)
3. Look for "Target Membership" section
4. ✅ Check the box next to "StrongGutAppClip"

#### Files to Share (in order of importance):

**Must Have (App won't build without these):**
- [ ] `GutSense/GutSense/KeychainService.swift`
      → Contains: CredentialsStore for API keys
- [ ] `GutSense/GutSense/QueryInputMode.swift`
      → Contains: QueryViewModel for food analysis
- [ ] `GutSense/GutSense/Models.swift`
      → Contains: All data models (AgentResult, UserProfile, etc.)
- [ ] `GutSense/GutSense/ThreePaneResultsView.swift`
      → Contains: Results display UI
- [ ] `GutSense/GutSense/FoundationModelAvailability.swift`
      → Contains: AppleFoundationModelService
- [ ] `GutSense/GutSense/BackendAPIService.swift`
      → Contains: API communication logic
- [ ] `GutSense/GutSense/ServingAmountView.swift`
      → Contains: Serving size UI (referenced by QueryViewModel)
- [ ] `GutSense/GutSense/DomainModels.swift`
      → Contains: Domain types and enums

### Step 2: Delete Unused Files

These auto-generated files are not needed:
- [ ] Delete `GutSense/StrongGutAppClip/Item.swift`

### Step 3: Build and Test

```bash
1. Select "StrongGutAppClip" scheme (dropdown near play button)
2. Choose iPhone simulator
3. Press ⌘R to build and run
```

**Expected Result:**
- ✅ App launches with "Strong Gut" title
- ✅ Shows hero section: "Know what's safe. Before you eat."
- ✅ Text input field for food queries
- ✅ Orange warning about API keys (if not configured)
- ✅ "Download GutSense" button at bottom

### Step 4: Configure Signing (if needed)

If you see signing errors:
1. Select StrongGutAppClip target
2. Signing & Capabilities tab
3. Select your Team
4. Xcode will auto-fix bundle ID and provisioning

---

## What's Already Done ✅

✅ **StrongGutAppClipApp.swift** - Entry point configured
✅ **ContentView.swift** - Complete UI with StrongGutClipView
✅ **Info.plist** - App Clip config + permissions
✅ **Design** - Matches your screenshot spec:
   - Hero icon with gradient
   - Tagline: "Know what's safe. Before you eat."
   - Simple text input
   - Feature list for full app
   - App Store CTA

## What This App Clip Does

### User Experience:
1. User scans QR code / taps NFC / clicks link
2. **Strong Gut App Clip** launches instantly (no install)
3. User types food query: "Garlic bread with olive oil"
4. Tap "Analyze Food"
5. See FODMAP analysis from 3 agents:
   - 🍎 Apple on-device AI
   - ⚡ Claude (Anthropic API)
   - 💎 Gemini (synthesis + recommendations)
6. Option to download full **GutSense** app

### Features Included:
✅ Text-based food query
✅ Three-agent FODMAP analysis
✅ Results with tier visualization
✅ App Store download CTA

### Features Excluded (full app only):
❌ Query history
❌ Photo / barcode input
❌ Source library
❌ Settings / preferences
❌ User profile customization

## Troubleshooting

### "Cannot find 'QueryViewModel' in scope"
→ You didn't add `QueryInputMode.swift` to target membership. Go back to Step 1.

### "Cannot find 'CredentialsStore' in scope"
→ You didn't add `KeychainService.swift` to target membership. Go back to Step 1.

### App builds but crashes on launch
→ Missing runtime files. Check you added ALL 8 files from Step 1.

### "Provisioning profile doesn't match"
→ Go to Signing & Capabilities, select your Team, let Xcode auto-fix.

## Next Steps After It Builds

1. **Test without API keys** - should show warning
2. **Add API keys in main GutSense app** - stored in Keychain (shared with App Clip)
3. **Test analysis flow** - enter "garlic bread", tap analyze
4. **Configure App Store Connect**:
   - Add App Clip Experience
   - Set invocation URL
   - Upload card image (3000×2000px)
5. **Deploy** with main app

## File Checklist Summary

Copy/paste this into your notes:

```
App Clip Target Membership Checklist:
✅ KeychainService.swift
✅ QueryInputMode.swift  
✅ Models.swift
✅ ThreePaneResultsView.swift
✅ FoundationModelAvailability.swift
✅ BackendAPIService.swift
✅ ServingAmountView.swift
✅ DomainModels.swift
```

---

**That's it!** After Step 1 (adding those 8 files), you should be able to build and run. 🚀

For detailed info, see `SETUP_GUIDE.md` in this folder.
