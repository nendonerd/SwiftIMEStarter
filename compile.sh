#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-Debug}"
PROJECT="SwiftIMEStarter.xcodeproj"
SCHEME="SwiftIMEStarter"
BUILD_DIR="$(pwd)/build"
NO_CODESIGN="${NO_CODESIGN:-1}"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "error: configuration must be Debug or Release"
  echo "usage: $0 [Debug|Release]"
  exit 1
fi

echo "Building $SCHEME ($CONFIGURATION)..."
XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$BUILD_DIR"
)

# Default to unsigned local builds so development does not depend on a local cert.
if [[ "$NO_CODESIGN" == "1" ]]; then
  XCODEBUILD_ARGS+=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=
  )
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" build

APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/SwiftIMEStarter.app"
echo "Build complete: $APP_PATH"
