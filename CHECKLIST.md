# StrongGutAppClip Setup Checklist

## Pre-Flight Check ✈️

Your App Clip target **StrongGutAppClip** has been created with:
- ✅ Name: **Strong Gut**
- ✅ Bundle ID: `com.headydiscy.isg.Clip`
- ✅ Entry point configured
- ✅ UI implemented
- ✅ Info.plist configured

---

## 📋 Setup Tasks

### Phase 1: Essential Files (MUST DO)

Add target membership for these 8 files:

#### Step-by-Step for Each File:
1. Find file in Project Navigator
2. Select it
3. Press ⌥⌘1 (or View → Inspectors → File Inspector)
4. Scroll to "Target Membership"
5. Check "StrongGutAppClip"

#### Files List:

- [ ] **KeychainService.swift**
  - Path: `GutSense/GutSense/KeychainService.swift`
  - Why: CredentialsStore for API keys
  - Status: ⏸️ NOT added yet

- [ ] **QueryInputMode.swift**
  - Path: `GutSense/GutSense/QueryInputMode.swift`
  - Why: QueryViewModel for analysis logic
  - Status: ⏸️ NOT added yet

- [ ] **Models.swift**
  - Path: `GutSense/GutSense/Models.swift`
  - Why: AgentResult, UserProfile, all data models
  - Status: ⏸️ NOT added yet

- [ ] **ThreePaneResultsView.swift**
  - Path: `GutSense/GutSense/ThreePaneResultsView.swift`
  - Why: Results display UI
  - Status: ⏸️ NOT added yet

- [ ] **FoundationModelAvailability.swift**
  - Path: `GutSense/GutSense/FoundationModelAvailability.swift`
  - Why: AppleFoundationModelService
  - Status: ⏸️ NOT added yet

- [ ] **BackendAPIService.swift**
  - Path: `GutSense/GutSense/BackendAPIService.swift`
  - Why: API communication
  - Status: ⏸️ NOT added yet

- [ ] **ServingAmountView.swift**
  - Path: `GutSense/GutSense/ServingAmountView.swift`
  - Why: Serving size UI
  - Status: ⏸️ NOT added yet

- [ ] **DomainModels.swift**
  - Path: `GutSense/GutSense/DomainModels.swift`
  - Why: Domain types
  - Status: ⏸️ NOT added yet

---

### Phase 2: Cleanup (OPTIONAL)

- [ ] Delete `GutSense/StrongGutAppClip/Item.swift` (unused)

---

### Phase 3: Build & Test

- [ ] Select "StrongGutAppClip" scheme in Xcode
- [ ] Choose iPhone simulator (iOS 17.0+)
- [ ] Press ⌘R to build and run
- [ ] Verify app launches with "Strong Gut" title
- [ ] Verify hero section shows: "Know what's safe. Before you eat."
- [ ] Verify text input field appears
- [ ] Verify "Analyze Food" button appears
- [ ] Verify orange warning about API keys (if not configured)
- [ ] Verify "Download GutSense" button at bottom

---

### Phase 4: Signing & Capabilities (AS NEEDED)

- [ ] Select StrongGutAppClip target
- [ ] Go to "Signing & Capabilities" tab
- [ ] Select your Team
- [ ] Verify Bundle ID: `com.headydiscy.isg.Clip`
- [ ] Add "Associated Domains" capability (for URL invocation)
  - [ ] Add domain: `appclips:yourdomain.com`

---

### Phase 5: Testing Scenarios

#### Test 1: Without API Keys
- [ ] Launch App Clip
- [ ] Should see orange warning card
- [ ] "Analyze Food" button should be disabled
- [ ] "Download GutSense" CTA should be visible

#### Test 2: With API Keys
- [ ] Configure API keys in main GutSense app (shared via Keychain)
- [ ] Launch App Clip
- [ ] Enter food query: "Garlic bread with olive oil"
- [ ] Tap "Analyze Food"
- [ ] Should navigate to results view
- [ ] Should show three panes (Apple, Claude, Gemini)

#### Test 3: App Store Link
- [ ] Tap "Download GutSense" button
- [ ] Should attempt to open App Store
- [ ] (Will fail in simulator, that's expected)

---

### Phase 6: App Store Connect (WHEN READY)

- [ ] Create App Clip experience in ASC
- [ ] Upload App Clip card image (3000×2000px)
  - Hero: Flask icon with tagline
  - Show food query example
  - Show three-pane results
  - Show risk percentage
- [ ] Set invocation URL (e.g., `https://gutsense.app/clip`)
- [ ] Configure card:
  - [ ] Title: "Quick Food Analysis"
  - [ ] Subtitle: "Know what's safe before you eat"
  - [ ] Action: "Open"
- [ ] Test via TestFlight
- [ ] Deploy with main app

---

## 🚨 Common Errors & Fixes

| Error | Fix |
|-------|-----|
| "Cannot find 'QueryViewModel'" | Add `QueryInputMode.swift` to target |
| "Cannot find 'CredentialsStore'" | Add `KeychainService.swift` to target |
| "Cannot find 'ThreePaneResultsView'" | Add `ThreePaneResultsView.swift` to target |
| "Cannot find 'AppleFoundationModelService'" | Add `FoundationModelAvailability.swift` to target |
| App crashes on launch | Missing one of the 8 required files |
| Signing error | Select your Team in Signing & Capabilities |
| Size limit exceeded (>15MB) | Remove unnecessary assets, use on-demand resources |

---

## 📊 Progress Tracker

```
Phase 1: Essential Files    [        ] 0/8 files added
Phase 2: Cleanup            [        ] 0/1 tasks done
Phase 3: Build & Test       [        ] 0/8 verifications
Phase 4: Signing            [        ] 0/5 tasks done
Phase 5: Testing            [        ] 0/3 scenarios tested
Phase 6: App Store Connect  [        ] 0/5 tasks done

Overall Progress: 0% complete
```

---

## 🎯 Success Criteria

Your App Clip is ready when:

✅ All 8 files have target membership
✅ App builds without errors
✅ App launches and shows hero section
✅ Text input and analyze button work
✅ Results navigate to ThreePaneResultsView
✅ "Download GutSense" button is visible
✅ Size is under 15MB uncompressed

---

## 📚 Documentation

- `QUICK_START.md` - Fast track setup (read this first!)
- `SETUP_GUIDE.md` - Detailed instructions and troubleshooting
- `CHECKLIST.md` - This file (task tracker)

---

**Start with Phase 1!** Add those 8 files and you'll be 80% done. 🚀
