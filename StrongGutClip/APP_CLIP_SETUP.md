# Strong Gut App Clip Setup Guide

## Overview
The Strong Gut App Clip provides a lightweight, instant-access experience for quick FODMAP food analysis. Users can access core functionality without installing the full GutSense app.

## Files Created
- `StrongGutApp.swift` - App Clip entry point
- `StrongGutClipView.swift` - Main UI for the App Clip
- `Info.plist` - App Clip configuration

## Manual Setup Steps in Xcode

### 1. Create App Clip Target
1. In Xcode, select your project in the Project Navigator
2. Click the "+" button at the bottom of the targets list
3. Choose "App Clip" from the template selector
4. Configure the App Clip:
   - Product Name: **StrongGut**
   - Team: Select your development team
   - Bundle Identifier: **com.headydiscy.isg.Clip** (must be parent bundle ID + ".Clip")
   - Language: Swift
   - User Interface: SwiftUI
5. Click "Finish"

### 2. Configure Build Settings
After creating the target, configure these settings:

#### General Tab:
- **Display Name**: Strong Gut
- **Bundle Identifier**: com.headydiscy.isg.Clip
- **Version**: Match your main app version
- **Minimum Deployments**: iOS 17.0 or later
- **Supported Destinations**: iPhone, iPad

#### Signing & Capabilities:
- Enable **Automatic Signing**
- Add capability: **App Groups** (match main app if needed)
- Add capability: **Associated Domains** for App Clip invocation URLs

### 3. Share Required Files with App Clip Target
In the Project Navigator, select these files and check the **StrongGut** target membership:

**Core Models:**
- `Models.swift`
- `DomainModels.swift`
- `QueryInputMode.swift`
- `KeychainService.swift`

**Services:**
- `BackendAPIService.swift`
- `FoundationModelAvailability.swift`

**Views (if needed):**
- `ThreePaneResultsView.swift`
- `ServingAmountView.swift`

**To add target membership:**
1. Select the file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Check the box next to "StrongGut" in Target Membership section

### 4. Replace Default Files
1. Delete the auto-generated files from the App Clip target:
   - `StrongGutApp.swift` (if different from ours)
   - `ContentView.swift` (default)
2. Use our custom files:
   - `StrongGutApp.swift` (already created)
   - `StrongGutClipView.swift` (already created)

### 5. Configure Info.plist
The `Info.plist` has been created with:
- `NSAppClip` dictionary with proper settings
- Camera and Photo Library usage descriptions
- Bundle display name: "Strong Gut"

If you need to update it:
1. Select `Info.plist` in the StrongGutClip folder
2. Add/modify keys as needed in the property list editor

### 6. Add App Clip Icon
1. Select `Assets.xcassets` in the App Clip target
2. Right-click → "App Icons & Launch Images" → "New iOS App Clip Icon"
3. Add icon images for all required sizes (1024×1024 for App Store)

### 7. Configure App Clip Experience
In App Store Connect:
1. Go to your app's page
2. Navigate to "App Clip" section
3. Add App Clip Experience:
   - **Advanced Experience URL**: Your invocation URL (e.g., `https://gutsense.app/clip`)
   - **Title**: "Quick Food Analysis"
   - **Subtitle**: "Know what's safe before you eat"
   - **Call to Action**: "Open"
   - **Header Image**: Upload 3000×2000px image
   - **App Clip Card**: Configure appearance

### 8. Associated Domains
1. Select the StrongGut App Clip target
2. Go to "Signing & Capabilities"
3. Add "Associated Domains" capability
4. Add domain: `appclips:gutsense.app` (replace with your domain)

### 9. Build and Test
1. Select the "StrongGut" scheme in Xcode
2. Choose a simulator or device
3. Build and run (⌘R)
4. Test the App Clip experience:
   - Enter a food query
   - Verify analysis works
   - Test "Download GutSense" button
   - Verify App Store link

### 10. Testing App Clip Invocation
**Via Local Experience:**
1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select "Run" on left sidebar
3. Under "Options" tab, find "_XCAppClipURL"
4. Enter your test URL: `https://gutsense.app/clip?food=garlic+bread`

**Via QR Code:**
1. Create a QR code with your App Clip URL
2. Use iOS Camera app to scan
3. Tap the App Clip card that appears

**Via NFC Tag:**
1. Write your App Clip URL to an NFC tag
2. Tap iPhone to the tag
3. App Clip card should appear

## App Clip Design Principles

### What We Include:
✅ Core food analysis functionality
✅ Simple text input (no photo/barcode in v1)
✅ Three-agent FODMAP analysis results
✅ Call-to-action to download full app

### What We Exclude:
❌ Query history
❌ Source library management
❌ Settings/preferences
❌ User profile customization
❌ Complex onboarding

## Size Optimization
App Clips must be under 15MB uncompressed:
- Use asset catalogs with on-demand resources
- Minimize included frameworks
- Share code with main app where possible
- Use SwiftUI for lightweight UI

## Animation Specification (from screenshot)
For 15-second animation arc:
- **0-2s**: App icon + tagline animation
- **2-6s**: Food query typing animation
- **6-10s**: Three panes lighting up sequentially with FODMAP tiers
- **10-13s**: Gemini synthesis card with risk percentage + enzyme recommendation
- **13-15s**: CTA - "Available on the App Store"

Use:
- SwiftUI `TimelineView` or `withAnimation` + `Task.sleep` sequencing
- App's actual color palette (green/amber/red FODMAP tiers)
- Real agent branding (Apple logo, Claude ⚡, Gemini icon)

## Troubleshooting

### "App Clip target not building"
- Ensure all shared files have target membership checked
- Verify bundle ID format: `parent.bundle.id.Clip`
- Check minimum deployment target matches

### "Missing dependencies"
- Add required frameworks to App Clip target
- Check that SwiftData model files are included

### "App Clip card not appearing"
- Verify Associated Domains are configured
- Check AASA file on your server
- Ensure URL scheme matches exactly

### "Size limit exceeded"
- Review included assets
- Remove unnecessary frameworks
- Use on-demand resources for large assets

## Next Steps
1. Complete manual setup steps 1-9 above
2. Test locally using local experiences
3. Submit to App Store Connect
4. Configure App Clip experiences in ASC
5. Test via TestFlight
6. Deploy to production

## Resources
- [Apple App Clips Documentation](https://developer.apple.com/documentation/app_clips)
- [App Clip Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-clips)
- [WWDC Videos on App Clips](https://developer.apple.com/videos/app-clips)
