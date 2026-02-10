#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-Debug}"
PROJECT="Typut.xcodeproj"
SCHEME="Typut"
BUILD_DIR="$(pwd)/build"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "error: configuration must be Debug or Release"
  echo "usage: $0 [Debug|Release]"
  exit 1
fi

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/Typut.app"
echo "Build complete: $APP_PATH"
