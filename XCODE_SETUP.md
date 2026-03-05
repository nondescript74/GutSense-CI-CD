# GutSense — Xcode Project Setup Guide
## From Zero to Running in ~15 Minutes

---

## What I Do vs What You Do

| Task | Who |
|---|---|
| Write all Swift files | ✅ Claude |
| Write FastAPI backend | ✅ Claude |
| Create Xcode project (.xcodeproj) | ⚠️ You (1 click) |
| Add Swift files to project | ⚠️ You (drag & drop) |
| Deploy backend to Railway | ⚠️ You (~5 min) |
| Enter API keys in the app | ⚠️ You (in-app UI) |

Claude cannot create `.xcodeproj` files — Xcode project files are binary XML bundles that require Xcode itself. But this takes you under 5 minutes.

---

## Step 1 — Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Fill in:
   - Product Name: `GutSense`
   - Team: Your Apple Developer account
   - Bundle ID: `com.yourname.gutsense`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData** ✅
4. Save to your preferred location

---

## Step 2 — Add All Swift Files

Drag all downloaded `.swift` files into the Xcode project navigator.
When prompted: ✅ **Copy items if needed** | ✅ **Add to GutSense target**

### Files to add (in order):

**Core Models & Services**
- `KeychainService.swift`
- `GutSenseApp.swift` ← Replace the auto-generated one

**Services**
- `BackendAPIService.swift`
- `AppleFoundationModelService.swift`

**ViewModels**
- `QueryViewModel.swift`

**Views**
- `APIKeysView.swift`
- `QueryInputView.swift`
- `ThreePaneResultsView.swift`

---

## Step 3 — Add Capabilities in Xcode

In Xcode: Select the **GutSense** target → **Signing & Capabilities**

Click **+ Capability** and add:
- **Camera** (for barcode + photo)
- **Photo Library** (for photo picker)

In `Info.plist`, add these keys:
```
NSCameraUsageDescription → "GutSense uses your camera to scan barcodes and food photos"
NSPhotoLibraryUsageDescription → "GutSense uses your photo library to analyze food images"
```

---

## Step 4 — Add FoundationModels Framework

1. Select **GutSense** target → **General** → **Frameworks, Libraries, and Embedded Content**
2. Click **+** → Search for `FoundationModels`
3. Add `FoundationModels.framework`

> **Note**: Requires iOS 18 SDK. If not found, update Xcode to 16.0+.

---

## Step 5 — Deploy the FastAPI Backend

### Option A — Railway (recommended, ~5 min)

```bash
# In your terminal
git init gutsense-backend && cd gutsense-backend
# Copy gutsense_backend_main.py here as main.py
pip freeze > requirements.txt  # or use the one below
```

**requirements.txt:**
```
fastapi==0.115.0
uvicorn==0.30.0
anthropic==0.34.0
google-generativeai==0.7.0
httpx==0.27.0
pydantic==2.8.0
```

**Procfile:**
```
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

1. Push to GitHub
2. Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub
3. Add environment variables in Railway dashboard:
   - `ANTHROPIC_API_KEY` = your Claude API key
   - `GEMINI_API_KEY` = your Gemini API key
4. Copy your Railway URL (e.g. `https://gutsense-xxx.railway.app`)

### Option B — Run locally for testing

```bash
pip install fastapi uvicorn anthropic google-generativeai httpx pydantic
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="AIza..."
uvicorn main:app --reload --port 8000
# Backend URL = http://YOUR_MAC_IP:8000
```

---

## Step 6 — Enter API Keys in the App

1. Build and run on your iPhone (or simulator for UI testing — Apple Foundation Models require real device)
2. Tap **Settings** tab → **API Keys & Credentials**
3. Enter:
   - **Anthropic API Key** → your `sk-ant-` key
   - **Gemini API Key** → your `AIza` key
   - **GutSense Backend URL** → your Railway URL
4. The green "Ready for Analysis" banner will appear

---

## Step 7 — Run Your First Query

1. Tap **Analyze** tab
2. Type: `Garlic bread with olive oil — safe for IBS-D?`
3. Tap **Analyze Food**
4. Watch all three panes populate:
   - 🍎 Apple pane updates first (on-device, ~300ms)
   - 🤖 Claude pane updates second (~2-4s)
   - 🧠 Gemini synthesis pane updates last (~4-6s)

---

## File Map (All Files Claude Will Build)

```
GutSense/
├── App/
│   └── GutSenseApp.swift           ✅ Done
├── Services/
│   ├── KeychainService.swift       ✅ Done
│   ├── BackendAPIService.swift     ✅ Done
│   └── AppleFoundationModelService.swift ✅ Done
├── ViewModels/
│   └── QueryViewModel.swift        ✅ Done
├── Views/
│   ├── APIKeysView.swift           ✅ Done
│   ├── Query/
│   │   └── QueryInputView.swift    ✅ Done
│   └── Panes/
│       └── ThreePaneResultsView.swift ✅ Done
└── Backend/
    └── main.py (gutsense_backend_main.py) ✅ Done
```

---

## Common Build Errors & Fixes

| Error | Fix |
|---|---|
| `Cannot find type 'LanguageModelSession'` | Add FoundationModels.framework to target |
| `No such module 'FoundationModels'` | Requires Xcode 16+ and iOS 18 SDK |
| `Missing UserProfile` type | GutSenseApp.swift must be in target |
| `Redeclaration of FODMAPTier` | ThreePaneResultsView.swift and GutSenseApp.swift define shared types — move enums to a shared `Models.swift` if Xcode flags duplicates |

---

*GutSense Setup Guide v1.0*
