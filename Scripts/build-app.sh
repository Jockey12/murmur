#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.whisperdict.app"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
"$ROOT/Scripts/build-whisper.sh"
cd "$ROOT"
swift build -c release
# Keep the runnable app outside SwiftPM's .build directory. SwiftPM owns that
# directory and may remove arbitrary bundle contents during a later build/test.
APP="$ROOT/dist/WhisperDict.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers"
cp "$ROOT/.build/release/WhisperDict" "$APP/Contents/MacOS/WhisperDict"
BUILD="$ROOT/.build/deps/whisper-build"
cp "$BUILD/bin/whisper-cli" "$APP/Contents/Helpers/whisper-cli"
cp "$BUILD/src"/*.dylib "$APP/Contents/Helpers/"
cp "$BUILD/ggml/src"/*.dylib "$APP/Contents/Helpers/"
cp "$BUILD/ggml/src/ggml-metal"/*.dylib "$APP/Contents/Helpers/"
cp "$BUILD/ggml/src/ggml-blas"/*.dylib "$APP/Contents/Helpers/"
install_name_tool -delete_rpath "$BUILD/src" -delete_rpath "$BUILD/ggml/src" -delete_rpath "$BUILD/ggml/src/ggml-blas" -delete_rpath "$BUILD/ggml/src/ggml-metal" -add_rpath @executable_path "$APP/Contents/Helpers/whisper-cli"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WhisperDict</string>
<key>CFBundleIdentifier</key><string>com.whisperdict.app</string>
<key>CFBundleName</key><string>WhisperDict</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSMicrophoneUsageDescription</key><string>WhisperDict records speech only when you start recording so it can transcribe it locally.</string>
</dict></plist>
PLIST
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  # Keep the TCC requirement stable across local rebuilds. A release build must
  # instead use a real Developer ID identity via CODESIGN_IDENTITY.
  codesign --force --deep --sign - --identifier "$BUNDLE_ID" --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP"
else
  codesign --force --deep --sign "$CODESIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
printf 'Created %s\n' "$APP"
