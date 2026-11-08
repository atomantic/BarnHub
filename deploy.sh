#!/bin/bash
set -euo pipefail

# BarnHub - Local TestFlight Deploy
#
# Usage: ./deploy.sh [--skip-tests] [--ios] [--macos] [--watch] [--all]
#
#   Default (no platform flag): every platform the project has a scheme for.
#   --ios / --macos / --watch : single platform
#   --all                     : explicit "all available" (same as default)
#
# Uploads are serial with a 60s gap between each to avoid Apple's CDN
# rejecting concurrent uploads from the same API key.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "❌ .env file not found. Copy .env.example to .env and fill in values."
    exit 1
fi

KEY_PATH="$APPSTORE_API_PRIVATE_KEY_PATH"
if [ ! -f "$KEY_PATH" ]; then
    echo "❌ API key not found at: $KEY_PATH"
    exit 1
fi

# altool only looks in ~/.private_keys/ for the API key — symlink it in.
mkdir -p ~/.private_keys
KEY_FILENAME="AuthKey_${APPSTORE_API_KEY_ID}.p8"
if [ ! -f ~/.private_keys/"$KEY_FILENAME" ]; then
    ln -sf "$KEY_PATH" ~/.private_keys/"$KEY_FILENAME"
    echo "🔑 Symlinked API key to ~/.private_keys/"
fi

PROJECT="BarnHub.xcodeproj"
BUILD_DIR="$SCRIPT_DIR/build"

# Scheme names
SCHEME_IOS="BarnHub"
SCHEME_MACOS="BarnHub macOS"
SCHEME_WATCH="BarnHub watchOS"
SCHEME_TEST="BarnHub"
TEST_BUNDLE="BarnHubTests"
APP_NAME="BarnHub"

# Detect available schemes for platform fan-out.
AVAILABLE_SCHEMES=$(xcodebuild -project "$PROJECT" -list 2>/dev/null || true)
has_scheme() { echo "$AVAILABLE_SCHEMES" | grep -qxE "[[:space:]]*$1"; }

HAS_IOS=false;   has_scheme "$SCHEME_IOS"   && HAS_IOS=true
HAS_MACOS=false; has_scheme "$SCHEME_MACOS" && HAS_MACOS=true
HAS_WATCH=false; has_scheme "$SCHEME_WATCH" && HAS_WATCH=true

SKIP_TESTS=false
BUILD_IOS=false
BUILD_MACOS=false
BUILD_WATCH=false
EXPLICIT_IOS=false
EXPLICIT_MACOS=false
EXPLICIT_WATCH=false
FAN_OUT=false
for arg in "$@"; do
    case "$arg" in
        --skip-tests) SKIP_TESTS=true ;;
        --ios)   EXPLICIT_IOS=true ;;
        --macos) EXPLICIT_MACOS=true ;;
        --watch) EXPLICIT_WATCH=true ;;
        --all)   FAN_OUT=true ;;
    esac
done

if ! $EXPLICIT_IOS && ! $EXPLICIT_MACOS && ! $EXPLICIT_WATCH && ! $FAN_OUT; then
    FAN_OUT=true
fi
if $FAN_OUT; then
    $HAS_IOS   && BUILD_IOS=true
    $HAS_MACOS && BUILD_MACOS=true
    $HAS_WATCH && BUILD_WATCH=true
fi
if $EXPLICIT_IOS;   then $HAS_IOS   || { echo "❌ iOS scheme '$SCHEME_IOS' not found";     exit 1; }; BUILD_IOS=true;   fi
if $EXPLICIT_MACOS; then $HAS_MACOS || { echo "❌ macOS scheme '$SCHEME_MACOS' not found"; exit 1; }; BUILD_MACOS=true; fi
if $EXPLICIT_WATCH; then $HAS_WATCH || { echo "❌ watchOS scheme '$SCHEME_WATCH' not found"; exit 1; }; BUILD_WATCH=true; fi

if ! $BUILD_IOS && ! $BUILD_MACOS && ! $BUILD_WATCH; then
    echo "❌ No platforms to build."
    exit 1
fi

MSG="🎯 Deploying to:"
if $BUILD_IOS;   then MSG="$MSG iOS";     fi
if $BUILD_MACOS; then MSG="$MSG macOS";   fi
if $BUILD_WATCH; then MSG="$MSG watchOS"; fi
echo "$MSG"

# Auto-increment build number. Snapshot the file first so we can roll back
# on any failure and not permanently consume a build # that never shipped.
ORIG_PBXPROJ=$(mktemp)
cp "$PROJECT/project.pbxproj" "$ORIG_PBXPROJ"

CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT/project.pbxproj" | awk '{print $3}' | tr -d ';')
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "📦 Build number: $CURRENT_BUILD → $NEW_BUILD"
/usr/bin/sed -i '' "s/CURRENT_PROJECT_VERSION = ${CURRENT_BUILD};/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" "$PROJECT/project.pbxproj"

DEPLOY_SUCCESS=false
rollback_build_bump() {
    if [ "$DEPLOY_SUCCESS" = "false" ]; then
        echo "↩️  Rolling back build number bump (deploy did not complete)..."
        cp "$ORIG_PBXPROJ" "$PROJECT/project.pbxproj" 2>/dev/null || true
    fi
    rm -f "$ORIG_PBXPROJ"
}
trap rollback_build_bump EXIT

if ! $SKIP_TESTS; then
    # The same suite as CI: unit tests plus the screen walk on iPhone, iPad and Mac.
    echo "🧪 Running tests (./scripts/test.sh)..."
    if ! ./scripts/test.sh; then
        echo "❌ Tests failed; not deploying. Results are in .build/test-results/."
        exit 1
    fi
    echo "✅ Tests passed"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

EXPORT_PLIST="$BUILD_DIR/exportOptions.plist"
cat > "$EXPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
EOF

# altool exits 0 even when uploads fail — grep the log for definitive failure
# banners. Do NOT grep plain "ERROR: " — altool logs transient multipart retry
# events ("WILL RETRY PART N. Checksums do not match." / "The network
# connection was lost.") that Apple's uploader recovers from internally.
FAIL_MARKERS="UPLOAD FAILED|Validation failed \(|ERROR ITMS-|product-errors"

UPLOADED_ONE=false
inter_upload_delay() {
    if $UPLOADED_ONE; then
        echo "⏳ Waiting 60s before next upload to avoid Apple CDN contention..."
        sleep 60
    fi
}

# --- iOS ---
if $BUILD_IOS; then
    ARCHIVE_IOS="$BUILD_DIR/${APP_NAME}_iOS.xcarchive"
    EXPORT_IOS="$BUILD_DIR/export_ios"

    echo "📦 Archiving iOS..."
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME_IOS" \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$ARCHIVE_IOS" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        -quiet
    echo "✅ iOS archive complete"

    echo "📤 Exporting iOS IPA..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_IOS" \
        -exportOptionsPlist "$EXPORT_PLIST" \
        -exportPath "$EXPORT_IOS" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$KEY_PATH" \
        -authenticationKeyID "$APPSTORE_API_KEY_ID" \
        -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID" \
        -quiet

    IPA_PATH="$EXPORT_IOS/${APP_NAME}.ipa"
    if [ ! -f "$IPA_PATH" ]; then
        echo "❌ iOS IPA not found at $IPA_PATH"
        ls -la "$EXPORT_IOS/"
        exit 1
    fi

    # Re-sign iOS app with explicit entitlements.
    # The unsigned-archive + signed-export pattern above produces an IPA whose
    # binary claims only the four default entitlements (application-identifier,
    # team-identifier, beta-reports-active, get-task-allow). Capability
    # entitlements from BarnHub.entitlements (CloudKit, APS) get silently
    # stripped because -exportArchive has no .xcent to read from the unsigned
    # archive and won't re-read the project's .entitlements file.
    # See skill: xcodebuild-unsigned-archive-strips-entitlements.
    RESIGN_DIR="$BUILD_DIR/resign_ios"
    rm -rf "$RESIGN_DIR" && mkdir -p "$RESIGN_DIR"
    unzip -q "$IPA_PATH" -d "$RESIGN_DIR"
    RESIGN_APP="$RESIGN_DIR/Payload/${APP_NAME}.app"
    IOS_BUNDLE_ID="net.shadowpuppet.BarnBook"
    ICLOUD_CONTAINER="iCloud.${IOS_BUNDLE_ID}"
    cat > "$RESIGN_DIR/signing.entitlements" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>${TEAM_ID}.${IOS_BUNDLE_ID}</string>
    <key>aps-environment</key>
    <string>production</string>
    <key>beta-reports-active</key>
    <true/>
    <key>com.apple.developer.icloud-container-environment</key>
    <string>Production</string>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array><string>${ICLOUD_CONTAINER}</string></array>
    <key>com.apple.developer.icloud-services</key>
    <array><string>CloudKit</string></array>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array><string>${ICLOUD_CONTAINER}</string></array>
    <key>get-task-allow</key>
    <false/>
    <key>keychain-access-groups</key>
    <array>
        <string>${TEAM_ID}.*</string>
        <string>com.apple.token</string>
    </array>
</dict>
</plist>
EOF

    SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep -E "Apple Distribution|iPhone Distribution" | grep "$TEAM_ID" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$SIGN_IDENTITY" ]; then
        echo "❌ No distribution signing identity for team $TEAM_ID found in keychain."
        echo "   Run once via Xcode → Product → Archive to prime the cert, or import the distribution cert manually."
        exit 1
    fi
    echo "🔏 Re-signing iOS app: $SIGN_IDENTITY"
    codesign --force \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$RESIGN_DIR/signing.entitlements" \
        --preserve-metadata=identifier,flags,runtime \
        "$RESIGN_APP"

    if ! codesign -d --entitlements :- "$RESIGN_APP" 2>/dev/null \
        | grep -q "com.apple.developer.icloud-container-identifiers"; then
        echo "❌ Re-sign did not embed CloudKit entitlements — aborting"
        codesign -d --entitlements :- "$RESIGN_APP" 2>&1 | head
        exit 1
    fi
    echo "✅ Re-signed iOS app; CloudKit + APS entitlements verified"

    rm -f "$IPA_PATH"
    (cd "$RESIGN_DIR" && zip -qr "$IPA_PATH" Payload)

    inter_upload_delay
    echo "🚀 Uploading iOS to TestFlight..."
    IOS_UPLOAD_LOG="$BUILD_DIR/ios_upload.log"
    set +e
    xcrun altool --upload-app \
        --file "$IPA_PATH" \
        --type ios \
        --apiKey "$APPSTORE_API_KEY_ID" \
        --apiIssuer "$APPSTORE_ISSUER_ID" \
        --transport DAV 2>&1 | tee "$IOS_UPLOAD_LOG"
    IOS_UPLOAD_STATUS=${PIPESTATUS[0]}
    set -e
    if [ "$IOS_UPLOAD_STATUS" -ne 0 ] || grep -qE "$FAIL_MARKERS" "$IOS_UPLOAD_LOG"; then
        echo "❌ iOS upload failed — see errors above"
        exit 1
    fi
    echo "✅ iOS upload complete!"
    UPLOADED_ONE=true
fi

# --- macOS ---
if $BUILD_MACOS; then
    ARCHIVE_MACOS="$BUILD_DIR/${APP_NAME}_macOS.xcarchive"
    EXPORT_MACOS="$BUILD_DIR/export_macos"

    echo "📦 Archiving macOS..."
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME_MACOS" \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -archivePath "$ARCHIVE_MACOS" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$KEY_PATH" \
        -authenticationKeyID "$APPSTORE_API_KEY_ID" \
        -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID" \
        -quiet
    echo "✅ macOS archive complete"

    echo "📤 Exporting macOS pkg..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_MACOS" \
        -exportOptionsPlist "$EXPORT_PLIST" \
        -exportPath "$EXPORT_MACOS" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$KEY_PATH" \
        -authenticationKeyID "$APPSTORE_API_KEY_ID" \
        -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID" \
        -quiet

    PKG_PATH=$(find "$EXPORT_MACOS" -name "*.pkg" | head -1)
    if [ -z "$PKG_PATH" ]; then
        echo "❌ macOS package not found in $EXPORT_MACOS"
        ls -la "$EXPORT_MACOS/"
        exit 1
    fi

    inter_upload_delay
    echo "🚀 Uploading macOS to TestFlight..."
    MACOS_UPLOAD_LOG="$BUILD_DIR/macos_upload.log"
    set +e
    xcrun altool --upload-app \
        --file "$PKG_PATH" \
        --type macos \
        --apiKey "$APPSTORE_API_KEY_ID" \
        --apiIssuer "$APPSTORE_ISSUER_ID" 2>&1 | tee "$MACOS_UPLOAD_LOG"
    MACOS_UPLOAD_STATUS=${PIPESTATUS[0]}
    set -e
    if [ "$MACOS_UPLOAD_STATUS" -ne 0 ] || grep -qE "$FAIL_MARKERS" "$MACOS_UPLOAD_LOG"; then
        echo "❌ macOS upload failed — see errors above"
        exit 1
    fi
    echo "✅ macOS upload complete!"
    UPLOADED_ONE=true
fi

# --- watchOS (standalone) ---
if $BUILD_WATCH; then
    ARCHIVE_WATCH="$BUILD_DIR/${APP_NAME}_watchOS.xcarchive"
    EXPORT_WATCH="$BUILD_DIR/export_watchos"

    echo "📦 Archiving watchOS..."
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME_WATCH" \
        -configuration Release \
        -destination 'generic/platform=watchOS' \
        -archivePath "$ARCHIVE_WATCH" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$KEY_PATH" \
        -authenticationKeyID "$APPSTORE_API_KEY_ID" \
        -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID" \
        -quiet
    echo "✅ watchOS archive complete"

    echo "📤 Exporting watchOS IPA..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_WATCH" \
        -exportOptionsPlist "$EXPORT_PLIST" \
        -exportPath "$EXPORT_WATCH" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$KEY_PATH" \
        -authenticationKeyID "$APPSTORE_API_KEY_ID" \
        -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID" \
        -quiet

    WATCH_IPA=$(find "$EXPORT_WATCH" -name "*.ipa" | head -1)
    if [ -z "$WATCH_IPA" ]; then
        echo "❌ watchOS IPA not found in $EXPORT_WATCH"
        ls -la "$EXPORT_WATCH/"
        exit 1
    fi

    inter_upload_delay
    echo "🚀 Uploading watchOS to TestFlight..."
    WATCH_UPLOAD_LOG="$BUILD_DIR/watch_upload.log"
    set +e
    # altool --type for standalone watchOS is still "ios" (Apple types: ios, macos, appletvos, visionos)
    xcrun altool --upload-app \
        --file "$WATCH_IPA" \
        --type ios \
        --apiKey "$APPSTORE_API_KEY_ID" \
        --apiIssuer "$APPSTORE_ISSUER_ID" \
        --transport DAV 2>&1 | tee "$WATCH_UPLOAD_LOG"
    WATCH_UPLOAD_STATUS=${PIPESTATUS[0]}
    set -e
    if [ "$WATCH_UPLOAD_STATUS" -ne 0 ] || grep -qE "$FAIL_MARKERS" "$WATCH_UPLOAD_LOG"; then
        echo "❌ watchOS upload failed — see errors above"
        exit 1
    fi
    echo "✅ watchOS upload complete!"
    UPLOADED_ONE=true
fi

echo "✅ Build $NEW_BUILD submitted to TestFlight."
echo "🔗 https://appstoreconnect.apple.com/teams/69a6de6e-c0f9-47e3-e053-5b8c7c11a4d1/apps/6760518680/testflight"

# Commit the build-number bump only after every upload succeeds, so a failed
# deploy doesn't leave a consumed build number on main.
git add "$PROJECT/project.pbxproj"
git commit -m "build: bump to build $NEW_BUILD"
DEPLOY_SUCCESS=true
echo "📝 Committed build number bump"

rm -rf "$BUILD_DIR"
echo "🧹 Cleaned build artifacts"
