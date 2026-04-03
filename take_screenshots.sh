#!/bin/bash
#
# take_screenshots.sh — Capture App Store Connect screenshots for all languages and devices.
#
# Usage:
#   ./take_screenshots.sh                       # all languages, all devices
#   ./take_screenshots.sh en                    # single language, all devices
#   ./take_screenshots.sh en de fr              # specific languages, all devices
#   ./take_screenshots.sh --iphone-only         # all languages, iPhone only
#   ./take_screenshots.sh --ipad-only           # all languages, iPad only
#   ./take_screenshots.sh --screen 01_home      # only capture one screen, all languages/devices
#   ./take_screenshots.sh --screen 01_home en   # one screen, specific language
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/BarnHub.xcodeproj"
SCHEME="BarnHub"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"
# Write config to both project dir and /tmp for simulator clone compatibility
CONFIG_FILE_PROJECT="$PROJECT_DIR/.screenshot_config.json"
CONFIG_FILE_TMP="/tmp/barnhub_screenshot_config.json"
DERIVED_DATA="$PROJECT_DIR/.build/DerivedData"

# App Store Connect screenshot device specs
# Format: "Simulator Name|OS version|folder_name|test_method"
IPHONE_DEVICE="iPhone 16 Pro Max|18.6|iphone_6.7|testCaptureIPhoneScreenshots"
IPAD_DEVICE="iPad Pro 13-inch (M4)|18.6|ipad_13|testCaptureIPadScreenshots"

# All supported languages (matching Localizable.xcstrings)
ALL_LANGUAGES=("en" "de" "fr" "nl" "sv" "es-ES" "es-MX" "pt-BR" "it")

# Currency code per locale (shown in screenshots)
currency_for_locale() {
    case "$1" in
        en)    echo "USD" ;;
        de|fr|nl|es-ES|it) echo "EUR" ;;
        sv)    echo "SEK" ;;
        es-MX) echo "MXN" ;;
        pt-BR) echo "BRL" ;;
        *)     echo "USD" ;;
    esac
}

# Parse arguments
LANGUAGES=()
DEVICES=()
SCREEN=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --iphone-only) DEVICES=("$IPHONE_DEVICE") ; shift ;;
        --ipad-only)   DEVICES=("$IPAD_DEVICE") ; shift ;;
        --screen)      SCREEN="$2" ; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--iphone-only|--ipad-only] [--screen <name>] [lang1 lang2 ...]"
            echo ""
            echo "Languages: ${ALL_LANGUAGES[*]}"
            echo "Devices: iPhone 16 Pro Max (6.7\"), iPad Pro 13\" (M4)"
            echo "Screens: 01_home 02_horses 03_horse_detail 04_clients 05_client_detail"
            echo "         06_schedule 07_accounting 08_reports 09_reports_charts 10_contract_types"
            exit 0
            ;;
        *)
            LANGUAGES+=("$1") ; shift ;;
    esac
done

# Defaults
[[ ${#LANGUAGES[@]} -eq 0 ]] && LANGUAGES=("${ALL_LANGUAGES[@]}")
[[ ${#DEVICES[@]} -eq 0 ]] && DEVICES=("$IPHONE_DEVICE" "$IPAD_DEVICE")

TOTAL_LANGS=${#LANGUAGES[@]}
TOTAL_DEVICES=${#DEVICES[@]}
TOTAL_RUNS=$((TOTAL_LANGS * TOTAL_DEVICES))
CURRENT_RUN=0
FAILED=()

echo "=========================================="
echo "  BarnHub App Store Screenshot Capture"
echo "=========================================="
echo "  Languages: ${LANGUAGES[*]}"
echo "  Devices:   $TOTAL_DEVICES"
echo "  Total runs: $TOTAL_RUNS"
[[ -n "$SCREEN" ]] && echo "  Screen:    $SCREEN"
echo "  Output:    $SCREENSHOTS_DIR/{locale}/{device}/"
echo "=========================================="
echo ""

write_config() {
    local locale="$1"
    local device="$2"
    local output="$3"
    local currency
    currency=$(currency_for_locale "$locale")
    cat > "$CONFIG_FILE_PROJECT" <<JSONEOF
{
    "locale": "$locale",
    "device": "$device",
    "output_dir": "$output",
    "currency": "$currency",
    "target_screen": "$SCREEN"
}
JSONEOF
    cp "$CONFIG_FILE_PROJECT" "$CONFIG_FILE_TMP" 2>/dev/null || true
}

# Build test bundles (once per device)
for device_spec in "${DEVICES[@]}"; do
    IFS='|' read -r DEVICE_NAME DEVICE_OS DEVICE_FOLDER TEST_METHOD <<< "$device_spec"

    echo "🔨 Building test bundle for $DEVICE_NAME..."
    xcodebuild build-for-testing \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$DEVICE_OS" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        -quiet 2>&1 || {
            echo "❌ Build failed for $DEVICE_NAME"
            exit 1
        }
    echo "✅ Build complete for $DEVICE_NAME"
    echo ""
done

# Boot simulators and pre-grant notification permissions
BUNDLE_ID="net.shadowpuppet.BarnBook"
for device_spec in "${DEVICES[@]}"; do
    IFS='|' read -r DEVICE_NAME _ _ _ <<< "$device_spec"
    echo "🚀 Booting $DEVICE_NAME simulator..."
    xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
done
sleep 3
for device_spec in "${DEVICES[@]}"; do
    IFS='|' read -r DEVICE_NAME _ _ _ <<< "$device_spec"
    xcrun simctl privacy "$DEVICE_NAME" grant notifications "$BUNDLE_ID" 2>/dev/null || true
done

# Capture screenshots
for device_spec in "${DEVICES[@]}"; do
    IFS='|' read -r DEVICE_NAME DEVICE_OS DEVICE_FOLDER TEST_METHOD <<< "$device_spec"

    for LANG in "${LANGUAGES[@]}"; do
        CURRENT_RUN=$((CURRENT_RUN + 1))
        echo "📸 [$CURRENT_RUN/$TOTAL_RUNS] $LANG on $DEVICE_NAME..."

        write_config "$LANG" "$DEVICE_FOLDER" "$SCREENSHOTS_DIR"

        if xcodebuild test-without-building \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$DEVICE_OS" \
            -derivedDataPath "$DERIVED_DATA" \
            -only-testing:"BarnHubUITests/ScreenshotTests/$TEST_METHOD" \
            CODE_SIGNING_ALLOWED=NO \
            -quiet 2>&1; then
            echo "   ✅ $LANG / $DEVICE_FOLDER complete"
        else
            echo "   ⚠️  $LANG / $DEVICE_FOLDER had failures (screenshots may still be saved)"
            FAILED+=("$LANG/$DEVICE_FOLDER")
        fi
    done
done

# Clean up config files
rm -f "$CONFIG_FILE_PROJECT" "$CONFIG_FILE_TMP"

# Summary
echo ""
echo "=========================================="
echo "  Screenshot Capture Complete"
echo "=========================================="

TOTAL_SCREENSHOTS=$(find "$SCREENSHOTS_DIR" -name "*.png" -newer "$PROJECT_DIR/take_screenshots.sh" 2>/dev/null | wc -l | tr -d ' ')
echo "  Screenshots captured: $TOTAL_SCREENSHOTS"
echo "  Output directory: $SCREENSHOTS_DIR/"
echo ""

# List output structure
for LANG in "${LANGUAGES[@]}"; do
    for device_spec in "${DEVICES[@]}"; do
        IFS='|' read -r _ _ DEVICE_FOLDER _ <<< "$device_spec"
        DIR="$SCREENSHOTS_DIR/$LANG/$DEVICE_FOLDER"
        if [[ -d "$DIR" ]]; then
            COUNT=$(ls "$DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
            echo "  $LANG/$DEVICE_FOLDER: $COUNT screenshots"
        fi
    done
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️  Runs with failures:"
    for f in "${FAILED[@]}"; do
        echo "  - $f"
    done
fi

echo ""
echo "Done! Upload screenshots to App Store Connect via Transporter or the web UI."
