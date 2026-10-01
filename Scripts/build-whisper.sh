#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/.build/deps"
SRC="$DEPS/whisper.cpp"
BUILD="$DEPS/whisper-build"
mkdir -p "$DEPS"
if [[ ! -d "$SRC/.git" ]]; then
  git clone --depth 1 --branch v1.7.4 https://github.com/ggerganov/whisper.cpp.git "$SRC"
fi
cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DGGML_METAL=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON
cmake --build "$BUILD" --config Release --target whisper-cli -j "$(sysctl -n hw.ncpu)"
printf 'Built whisper.cpp CLI: %s\n' "$BUILD/bin/whisper-cli"
