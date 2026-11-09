# i search

> **Circle to search, for your Mac.**  
> A polished native macOS menu bar utility that lets you select anything visible on your screen and receive instant AI-powered explanations.

---

## 🌟 Overview

**i search** brings the intuitive, fluid "circle to search" workflow to macOS. Always available in your menu bar or via a global keyboard shortcut (`⌘⇧1`), it dims your screen with a non-intrusive crosshair overlay. You simply drag around any visible area—even inside another application, browser, terminal, or video—and i search captures the region, presents a compact floating review panel, and delivers rich explanations, OCR transcriptions, or answers to custom questions using vision-capable AI models.

### Key Capabilities

- 🎯 **Native macOS Overlay**: System-wide global shortcut (`⌘⇧1`, fully customizable) activates a transparent, dimmed overlay with crosshair pointer, dimension badge (e.g. `480 × 320 pt`), and interactive resize handles.
- ⚡ **Precision Screen Capture**: Uses Apple's modern **ScreenCaptureKit** (with CoreGraphics fallback), respecting Retina display backing scale factors (2x pixel density) and multi-display setups.
- 💬 **Google Circle to Search Experience**: Floating translucent search overlay equipped with a free-text search box. Search with or without a question:
  - **Without a question**: Immediately analyzes and explains the selected item.
  - **With a question**: Combines the selected visual item with your question (e.g. *"Is it safe for cats?"*) in clear, simple language.
- 🎯 **Native macOS Overlay**: System-wide global shortcut (`⌘⇧1`, fully customizable). Select anything visible on your screen by **circling, highlighting, or tapping it**, with immediate release confirmation.
- 🧠 **Pluggable AI Services**:
  - **Google Gemini**: Gemini 2.0 Flash, 1.5 Flash, 1.5 Pro via REST API.
  - **OpenAI & Compatible**: GPT-4o, GPT-4o-mini, Ollama, Groq, or OpenRouter with custom base URLs.
  - **Anthropic Claude**: Claude 3.5 Sonnet, Claude 3.5 Haiku.
  - **Demo Mode (Offline)**: Built-in zero-configuration mode using **Apple's Neural Vision framework** (`VNRecognizeTextRequest`) for on-device OCR and offline analysis—no API keys or internet connection required!
- 🔐 **Privacy First**:
  - Captured images are held **strictly in-memory** and discarded immediately when the session ends.
  - **No background recording** or automated screenshots.
  - Nothing is sent to an AI service until you explicitly click **Submit**.
  - API keys are securely encrypted in the **macOS Keychain** (`com.isearch.app`).

---

## 🏗️ Project Architecture

```
i_search/
├── Package.swift                    # Swift Package Manager manifest
├── project.yml                      # XcodeGen specification
├── i search.xcodeproj/             # Complete Xcode project (openable directly in Xcode)
├── scripts/
│   ├── build_app.sh                 # Release build, .app bundling, and code-signing
│   └── verify_components.swift      # Automated verification suite for core modules
├── Resources/
│   ├── Info.plist                   # Bundle metadata, LSUIElement=true, permissions
│   └── i_search.entitlements        # Outbound network entitlements
└── Sources/
    └── ISearch/
        ├── main.swift               # Application entry point with @MainActor isolation
        ├── App/
        │   ├── AppDelegate.swift    # App lifecycle, menu bar setup, shortcut binding
        │   ├── AppState.swift       # Central state machine (selection, capture, AI queries)
        │   └── MenuBarManager.swift # NSStatusItem & menu handling
        ├── Shortcut/
        │   ├── KeyCombo.swift       # Keycode & modifier representation with display strings
        │   └── GlobalShortcutManager.swift # Carbon RegisterEventHotKey management
        ├── Capture/
        │   ├── PermissionManager.swift    # Screen Recording permission status & settings helper
        │   └── ScreenCaptureService.swift # ScreenCaptureKit & CoreGraphics capture engine
        ├── Image/
        │   └── ImageProcessor.swift       # Thumbnail generation, JPEG compression, base64 encoding
        ├── Overlay/
        │   ├── SelectionGeometry.swift          # Handle hit testing, rectangle math, shape support
        │   ├── SelectionOverlayView.swift       # Dimmed scrim, clear cutout, handles, badges
        │   └── SelectionOverlayController.swift # Window controller managing screen overlay
        ├── AI/
        │   ├── AIServiceProtocol.swift    # Vision AI provider protocol & error types
        │   ├── AIConfiguration.swift      # Model mappings, active provider, Keychain accounts
        │   ├── KeychainHelper.swift       # macOS Security framework wrapper + env fallback
        │   ├── MockAIService.swift        # On-device Apple Vision OCR demo analyzer
        │   ├── GeminiAIService.swift      # Google Gemini 2.0/1.5 API client
        │   ├── OpenAIAIService.swift      # OpenAI GPT-4o / custom endpoint client
        │   └── ClaudeAIService.swift      # Anthropic Claude Messages API client
        └── UI/
            ├── Components/
            │   ├── ActionChip.swift             # Reusable interactive chip button
            │   └── MarkdownTextView.swift       # Selectable, formatted typography view
            ├── FloatingPanel/
            │   ├── ResultsPanelController.swift # NSPanel floating utility window controller
            │   ├── ResultsPanelView.swift       # State coordinator (review, loading, response, error)
            │   ├── ReviewCardView.swift         # Free-text search box, thumbnail, Circle to Search style review card
            │   ├── LoadingStateView.swift       # Animated progress indicator with cancel action
            │   └── ResponseCardView.swift       # Answer display, copy button, follow-up input
            ├── Settings/
            │   ├── SettingsView.swift           # Preferences window with General, AI, Privacy tabs
            │   ├── AISettingsView.swift         # Provider picker, model input, Keychain key entry
            │   ├── ShortcutSettingsView.swift   # Shortcut recorder, presets, overlay tester
            │   └── PrivacyInfoView.swift        # Explicit data handling & privacy statement
            └── Onboarding/
                ├── WelcomeView.swift            # 3-step first-launch onboarding view
                └── WelcomeWindowController.swift# Onboarding window controller
```

---

## 🚀 Quick Start & Build Instructions

### Prerequisites
- macOS 14.0 (Sonoma) or later
- Xcode 15+ or Apple Command Line Tools (`swift --version` >= 5.9)

### 1. Build and Run via Xcode
1. Open `i search.xcodeproj` in Xcode (or open the project directory in Xcode).
2. Select the `i search` scheme and your Mac as the run destination.
3. Press **⌘R** to build and run.

### 2. Build the Standalone `.app` via Command Line
Run the bundled build script:
```bash
./scripts/build_app.sh
```
This compiles a Release binary with SwiftPM, packages the macOS application bundle at `build/i search.app`, and performs ad-hoc code signing.

To launch the app directly:
```bash
open "build/i search.app"
```

### 3. Run with Swift Package Manager
```bash
swift run "i search"
```

### 4. Run Automated Component Verifications
Verify all mathematical geometry, key combination encoding, image encoding, on-device Vision OCR, and Keychain helpers:
```bash
swiftc -parse-as-library -o test_runner \
       Sources/ISearch/Shortcut/KeyCombo.swift \
       Sources/ISearch/Overlay/SelectionGeometry.swift \
       Sources/ISearch/Image/ImageProcessor.swift \
       Sources/ISearch/AI/AIServiceProtocol.swift \
       Sources/ISearch/AI/MockAIService.swift \
       Sources/ISearch/AI/KeychainHelper.swift \
       scripts/verify_components.swift \
       -framework AppKit -framework Vision -framework Carbon -framework Security && \
./test_runner && rm test_runner
```

---

## 🔒 Permissions & Security

### Screen Recording Permission
macOS requires explicit **Screen Recording** permission before any app can capture screen content.

1. When you first launch **i search**, an onboarding window appears explaining the requirement.
2. Click **Grant in Settings** (or navigate to `System Settings` → `Privacy & Security` → `Screen Recording`).
3. Toggle the switch for **i search** to **ON**.
4. In **i search** Settings, click **Check Status** to verify that the permission indicator turns green.

> **Privacy Guarantee**: **i search** captures *only* the specific pixel region you drag over. It does not record your screen in the background, does not save screenshots to disk, and sends images to the AI service only after you click **Submit**.

---

## ⚙️ Configuration & API Credentials

**i search** does not hard-code any API keys. You can configure credentials in two convenient ways:

### Option A: In-App Settings (Stored in macOS Keychain)
1. Click the **i search** icon in your menu bar and select **Settings...** (or press `⌘,`).
2. Switch to the **AI Provider** tab.
3. Select your provider:
   - **Demo Mode**: No API key required! Uses Apple's Vision Neural Engine locally.
   - **Google Gemini**: Enter your Gemini API key (default model: `gemini-2.0-flash`).
   - **OpenAI**: Enter your OpenAI API key (default model: `gpt-4o-mini`). Also supports custom endpoints for Ollama or OpenRouter.
   - **Anthropic Claude**: Enter your Claude API key (default model: `claude-3-5-haiku-20241022`).
4. Click **Save** to encrypt the key in the macOS Keychain.
5. Click **Test Connection** to verify that your key and model are working properly.

### Option B: Environment Variables (Local Development)
For local development and automated workflows, **i search** also automatically falls back to environment variables:
- `GEMINI_API_KEY`: For Google Gemini
- `OPENAI_API_KEY`: For OpenAI / Compatible
- `ANTHROPIC_API_KEY`: For Anthropic Claude

---

## ⌨️ Global Shortcuts & Controls

| Shortcut / Action | Function |
|---|---|
| `⌘⇧1` (Default) | Activates the dimmed screen selection overlay |
| `Circle Gesture` | Draw a loop around any item on screen to select it |
| `Highlight / Drag` | Drag across text or visual areas to capture a selection |
| `Tap / Click` | Tap once on any item or word to create an automatic focus selection |
| `Return` / `Search` | Search selected item (without a question) or ask a question |
| `Escape` | Dismiss and return immediately to your active application |
| `⌘,` | Open Settings & Preferences |
| `⌘Q` | Quit i search |

---

## 🔍 Extensibility & Architecture Notes

- **Circular Selection Ready**: `SelectionGeometry.swift` and `SelectionOverlayView.swift` include native `SelectionShape.circle` support. Circular capture masks can be toggled without changing any capture, coordinate, or AI service logic.
- **Multi-Display Aware**: The overlay automatically detects the active display where the mouse pointer resides, properly translating AppKit display coordinates to ScreenCaptureKit coordinates with display backing scale factors.
- **Multi-Turn Follow-Ups**: Once an answer is displayed, you can ask follow-up questions about the same captured image without needing to re-select or re-upload.

---

## 📋 Current Limitations

1. **Sandboxing & Screen Recording**: ScreenCaptureKit requires Screen Recording permissions granted by the user in macOS System Settings. On unsigned command-line builds, macOS may prompt each time the binary path changes.
2. **Display Selection**: In the current version, the selection overlay activates on the display containing the cursor. Moving a selection rectangle across different physical displays simultaneously is constrained by display boundaries.
3. **Offline AI**: Full multimodal semantic reasoning requires an active internet connection to Gemini, OpenAI, or Claude. When offline, Demo Mode provides accurate text extraction and structural analysis using Apple's local Vision Neural Engine.

---

## 📄 License

MIT License. Designed with polish for macOS.
