# StrongGutAppClip Setup Guide

## Current Status
✅ App Clip target created: **StrongGutAppClip**
✅ Main app file updated: `StrongGutAppClipApp.swift`
✅ Content view implemented: `ContentView.swift` (now contains `StrongGutClipView`)
✅ Info.plist configured with App Clip settings and permissions
✅ Display name set to: **Strong Gut**

## Required Manual Steps

### 1. Share Required Files with App Clip Target

You need to add target membership for these files so the App Clip can use them:

#### Core Models (CRITICAL):
1. **Models.swift**
   - Contains: `FoodQueryRecord`, `UserSourceRecord`, `UserProfile`, `AgentResult`, etc.
   - Location: `GutSense/GutSense/Models.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip" under Target Membership

2. **DomainModels.swift**
   - Contains: Domain types and enums
   - Location: `GutSense/GutSense/DomainModels.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip"

3. **QueryInputMode.swift**
   - Contains: `QueryViewModel`, `QueryPhase`, serving amount logic
   - Location: `GutSense/GutSense/QueryInputMode.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip"

4. **KeychainService.swift**
   - Contains: `CredentialsStore` for API key management
   - Location: `GutSense/GutSense/KeychainService.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip"

#### Services (CRITICAL):
5. **BackendAPIService.swift**
   - Contains: API communication logic
   - Location: `GutSense/GutSense/BackendAPIService.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip"

6. **FoundationModelAvailability.swift**
   - Contains: `AppleFoundationModelService` for on-device AI
   - Location: `GutSense/GutSense/FoundationModelAvailability.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip"

#### Views (CRITICAL):
7. **ThreePaneResultsView.swift**
   - Contains: Results display with three-agent output
   - Location: `GutSense/GutSense/ThreePaneResultsView.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip"

8. **ServingAmountView.swift**
   - Contains: Serving size selection UI
   - Location: `GutSense/GutSense/ServingAmountView.swift`
   - Action: Select file → File Inspector → Check "StrongGutAppClip"

### 2. How to Add Target Membership

For each file listed above:
1. Open Xcode
2. Select the file in Project Navigator (left sidebar)
3. Open File Inspector (right sidebar) - use View → Inspectors → File or ⌥⌘1
4. Scroll to "Target Membership" section
5. Check the box next to "StrongGutAppClip"
6. The file will now be compiled as part of the App Clip

### 3. Verify Build Settings

Check these settings for the StrongGutAppClip target:

#### General Tab:
- **Display Name**: Strong Gut ✅ (already set in Info.plist)
- **Bundle Identifier**: Should be `com.headydiscy.isg.Clip` (parent + .Clip)
- **Version**: Should match main app version
- **Minimum Deployments**: iOS 17.0 or later
- **Supported Destinations**: iPhone, iPad

#### Signing & Capabilities:
- ✅ Automatic Signing enabled
- Add **Associated Domains** capability for App Clip URLs:
  - Format: `appclips:yourdomain.com`
  - Example: `appclips:gutsense.app`
- Add **App Groups** if sharing data with main app

### 4. Delete Unused Files

These were auto-generated and are no longer needed:
- `GutSense/StrongGutAppClip/Item.swift` - delete this
- The old template code has been replaced

### 5. App Clip Card Configuration

The App Clip implements the design from your screenshot:

**Visual Elements:**
- ✅ Hero icon (flask) with gradient
- ✅ Tagline: "Know what's safe. Before you eat."
- ✅ Subtitle: "FODMAP food safety analysis for IBS patients"
- ✅ Simple text input for food queries
- ✅ Analyze button with loading states
- ✅ API keys warning
- ✅ Feature list showing full app benefits
- ✅ App Store download CTA

**User Flow:**
1. User opens App Clip via QR code / NFC / URL
2. Sees hero section with tagline
3. Enters food query (e.g., "Garlic bread with olive oil")
4. Taps "Analyze Food"
5. Views three-pane results (Apple → Claude → Gemini synthesis)
6. Can download full GutSense app for more features

### 6. Test the App Clip

#### Build and Run:
```bash
1. Select "StrongGutAppClip" scheme in Xcode
2. Choose iPhone simulator (iOS 17.0+)
3. Press ⌘R to build and run
```

#### Test Scenarios:
1. **Without API Keys**:
   - Should show orange warning
   - Analyze button disabled
   - "Download GutSense" CTA visible

2. **With API Keys** (configure in Keychain):
   - Can enter food query
   - Analyze button enabled
   - Results navigate to ThreePaneResultsView

3. **App Store Link**:
   - Tap "Download GutSense"
   - Should attempt to open App Store (will fail in simulator)

#### Local Experience Testing:
1. Product → Scheme → Edit Scheme
2. Run → Options tab
3. Set "_XCAppClipURL" to test URL:
   - Example: `https://gutsense.app/clip?food=garlic+bread`
4. Run the App Clip
5. URL parameters can pre-fill the query

### 7. Configure Associated Domains

For App Clip invocation via URLs:

1. **In Xcode**:
   - Select StrongGutAppClip target
   - Signing & Capabilities tab
   - Add "Associated Domains" capability
   - Add domain: `appclips:yourdomain.com`

2. **On Your Server** (e.g., gutsense.app):
   - Create `.well-known/apple-app-site-association` file
   - Add App Clip configuration:
   ```json
   {
     "appclips": {
       "apps": ["TEAMID.com.headydiscy.isg.Clip"]
     }
   }
   ```

3. **In App Store Connect**:
   - Configure App Clip Experience
   - Set invocation URL
   - Upload card image (3000×2000px)
   - Set title, subtitle, action button

### 8. Size Optimization

App Clips must be **under 15MB uncompressed**:

Current optimizations:
- ✅ No SwiftData persistence (in-memory only)
- ✅ Shares code with main app
- ✅ SwiftUI for lightweight UI
- ✅ No query history or source library

To check size:
```bash
# After archive
xcrun dyld_info -size path/to/StrongGutAppClip.app
```

### 9. Animation Implementation (Future)

From your screenshot, the 15-second animation:
- 0-2s: App icon + tagline appear
- 2-6s: Food query typing animation
- 6-10s: Three panes light up sequentially
- 10-13s: Gemini synthesis card with risk %
- 13-15s: "Available on the App Store" CTA

**Implementation approach:**
```swift
// In StrongGutClipView, add animation states
@State private var animationPhase: Int = 0

// Use TimelineView or Task.sleep for sequencing
TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
    // Animate based on elapsed time
}
```

### 10. Troubleshooting

#### "Cannot find 'QueryViewModel' in scope"
→ Add `QueryInputMode.swift` to StrongGutAppClip target membership

#### "Cannot find 'CredentialsStore' in scope"
→ Add `KeychainService.swift` to StrongGutAppClip target membership

#### "Cannot find 'ThreePaneResultsView' in scope"
→ Add `ThreePaneResultsView.swift` to StrongGutAppClip target membership

#### "App Clip won't launch"
→ Check bundle identifier format: `parent.bundle.id.Clip`
→ Verify Info.plist has `NSAppClip` dictionary

#### "Size limit exceeded"
→ Remove unnecessary assets from target
→ Use on-demand resources for large images
→ Check that you're not including test frameworks

## Next Steps Checklist

- [ ] Add target membership for all 8 required files (Models, Services, Views)
- [ ] Delete unused `Item.swift` file
- [ ] Build and test in simulator
- [ ] Configure signing with your development team
- [ ] Add Associated Domains capability
- [ ] Test with local App Clip experience URL
- [ ] Create App Clip card artwork (3000×2000px)
- [ ] Configure in App Store Connect
- [ ] Test size constraints (< 15MB)
- [ ] Submit with main app to App Store

## Resources
- [Apple App Clips Documentation](https://developer.apple.com/documentation/app_clips)
- [App Clip HIG](https://developer.apple.com/design/human-interface-guidelines/app-clips)
- [WWDC App Clips Videos](https://developer.apple.com/videos/app-clips)

---

**Ready to test!** Start with step 1 (adding target membership) and work through the checklist.
