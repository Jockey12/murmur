# WhisperDict

WhisperDict is a native macOS menu-bar voice typing app. SwiftUI/AppKit provide the interface, AVAudioEngine captures microphone input, and transcription is performed by the real whisper.cpp command-line engine on-device. The engine interface is protocol-based so it can be replaced later.

## Build and run

Requirements: macOS 13+, Xcode command-line tools, Swift 6, CMake, and Git. The first build clones the pinned whisper.cpp v1.7.4 source and compiles its Metal-enabled CLI; this requires a network connection once. No Python or Node runtime is used.

```sh
chmod +x Scripts/*.sh
Scripts/build-app.sh
open dist/WhisperDict.app
```

For Swift-only iteration: `swift build` and `swift test`. The reproducible app bundle is created at `dist/WhisperDict.app`, outside SwiftPM's managed `.build` folder. The development script uses a stable local signing requirement so Accessibility access survives local rebuilds. For release distribution, sign and notarize with a real Developer ID identity: `CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Scripts/build-app.sh`. Install and grant Accessibility access to the exact `dist/WhisperDict.app` copy.

## Models

Open **Model Manager & Settings…** from the menu-bar icon and click **Download** beside a model. Downloads are initiated only by the user from the Hugging Face `ggerganov/whisper.cpp` repository. Models reside at `~/Library/Application Support/WhisperDict/models/`. Installed model selection is shown in Settings. Files may also be imported by placing valid `ggml-*.bin` files in that directory.

Available catalog entries: tiny, base, base English, small, medium, large-v3, and large-v3-turbo. Approximate sizes are shown in the manager.

## Permissions and local data

macOS requests microphone access the first time recording is started. Allow it in **System Settings → Privacy & Security → Microphone**. No audio, transcript, analytics, or telemetry is transmitted by the application. Model downloads are the only network activity and are explicit. Settings are stored in UserDefaults; models are stored in Application Support; audio buffers are held in memory during capture and no transcript history is persisted.

## Current implementation status

The app shell, Settings UI, persistent settings, explicit Hugging Face model downloads, AVAudioEngine capture, 16 kHz mono WAV preparation, local whisper.cpp inference, text cleanup, Control-Space toggle hotkey, basic RMS silence VAD, floating recording/transcribing overlay with audio level, and focused-app insertion are implemented. WhisperDict captures the target app before recording starts, attempts direct Accessibility insertion into that app, then activates and sends Command-V to the same app as a fallback. Clipboard contents are restored after fallback paste unless Copy transcription is enabled. Missing Accessibility permission is reported in Settings without stealing focus from the target app. Remaining work includes push-to-talk release detection, download progress reporting, microphone selection, and broader service/state tests. The app does not fake transcription.

The current CLI is built from the pinned upstream release with Metal and Accelerate enabled by `Scripts/build-whisper.sh`, then bundled with its dylibs in `Contents/Helpers`. The app invokes it asynchronously and uses the selected model file. `TranscriptionEngine` can be substituted without changing UI code. Microphone and Accessibility hardware/system-permission flows still need validation on a normal interactive desktop session.
