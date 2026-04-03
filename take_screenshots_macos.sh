#!/bin/bash
#
# take_screenshots_macos.sh — Capture macOS App Store screenshots for all languages.
#
# Prerequisites:
#   Your terminal app needs TWO macOS permissions (System Settings → Privacy & Security):
#     1. Screen Recording — to capture the app window
#     2. Accessibility — to navigate the sidebar via AppleScript
#   Grant these, then re-run the script.
#
# Usage:
#   ./take_screenshots_macos.sh              # all languages
#   ./take_screenshots_macos.sh en de        # specific languages
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/BarnHub.xcodeproj"
SCHEME="BarnHub macOS"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"
DERIVED_DATA="$PROJECT_DIR/.build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/BarnHub.app"

ALL_LANGUAGES=("en" "de" "fr" "nl" "sv" "es-ES" "es-MX" "pt-BR" "it")

# Currency per locale
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
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: $0 [lang1 lang2 ...]"
            echo "Languages: ${ALL_LANGUAGES[*]}"
            echo ""
            echo "Requires Screen Recording + Accessibility permissions for your terminal."
            exit 0
            ;;
        *) LANGUAGES+=("$arg") ;;
    esac
done
[[ ${#LANGUAGES[@]} -eq 0 ]] && LANGUAGES=("${ALL_LANGUAGES[@]}")

# macOS App Store screenshot size: 1280x800 minimum, Retina preferred
WINDOW_WIDTH=1440
WINDOW_HEIGHT=900

echo "=========================================="
echo "  BarnHub macOS Screenshot Capture"
echo "=========================================="
echo "  Languages: ${LANGUAGES[*]}"
echo "  Window: ${WINDOW_WIDTH}x${WINDOW_HEIGHT}"
echo "  Output: $SCREENSHOTS_DIR/{locale}/macos/"
echo "=========================================="
echo ""

# Build macOS app
echo "🔨 Building macOS app..."
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1 || {
        echo "❌ Build failed"
        exit 1
    }
echo "✅ Build complete"
echo ""

if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ App not found at $APP_PATH"
    exit 1
fi

# Get window ID for BarnHub via CGWindowListCopyWindowInfo
get_window_id() {
    swift -e '
    import Cocoa
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { exit(1) }
    for w in windowList {
        let owner = w[kCGWindowOwnerName as String] as? String ?? ""
        if owner == "BarnHub" {
            if let num = w[kCGWindowNumber as String] as? Int { print(num); break }
        }
    }
    ' 2>/dev/null
}

# Position and resize window
setup_window() {
    osascript -e "
    tell application \"System Events\"
        tell process \"BarnHub\"
            if (count of windows) > 0 then
                set position of first window to {100, 100}
                set size of first window to {$WINDOW_WIDTH, $WINDOW_HEIGHT}
            end if
        end tell
    end tell" 2>/dev/null
}

# Click a sidebar item by row number (1=Home, 2=Horses, 3=Clients, 4=Schedule, 5=Accounting)
click_sidebar() {
    local row="$1"
    osascript -e "
    tell application \"System Events\"
        tell process \"BarnHub\"
            tell outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1
                select row $row
            end tell
        end tell
    end tell" 2>/dev/null || true
}

# Take screenshot of BarnHub window
capture_window() {
    local output_path="$1"
    osascript -e 'tell application "BarnHub" to activate' 2>/dev/null
    sleep 0.5
    local wid
    wid=$(get_window_id)
    if [[ -n "$wid" ]]; then
        screencapture -l "$wid" -o -x "$output_path" 2>/dev/null
    else
        # Fallback: capture by screen region
        screencapture -R "100,100,${WINDOW_WIDTH},${WINDOW_HEIGHT}" -o -x "$output_path" 2>/dev/null
    fi
}

# Capture screenshots for one language
capture_locale() {
    local lang="$1"
    local currency
    currency=$(currency_for_locale "$lang")
    local out_dir="$SCREENSHOTS_DIR/$lang/macos"
    mkdir -p "$out_dir"

    echo "📸 Capturing $lang (currency: $currency)..."

    # Kill any existing instance
    killall BarnHub 2>/dev/null || true
    sleep 1

    # Launch with locale + sample data
    open "$APP_PATH" --args \
        -SeedSampleData \
        -ForceProMode \
        -net.shadowpuppet.BarnBook.appLocale "$lang" \
        -net.shadowpuppet.BarnBook.currencyCode "$currency" \
        -AppleLanguages "($lang)" \
        -AppleLocale "$lang"

    sleep 4
    setup_window
    sleep 1

    # 1. Home (row 1 — already selected by default)
    capture_window "$out_dir/01_home.png"

    # 2. Horses (row 2)
    click_sidebar 2
    sleep 1
    capture_window "$out_dir/02_horses.png"

    # 3. Clients (row 3)
    click_sidebar 3
    sleep 1
    capture_window "$out_dir/03_clients.png"

    # 4. Schedule (row 4)
    click_sidebar 4
    sleep 1
    capture_window "$out_dir/04_schedule.png"

    # 5. Accounting (row 5)
    click_sidebar 5
    sleep 1
    capture_window "$out_dir/05_accounting.png"

    # Quit
    killall BarnHub 2>/dev/null || true
    sleep 1

    local count
    count=$(ls "$out_dir"/*.png 2>/dev/null | wc -l | tr -d ' ')
    echo "   ✅ $lang/macos: $count screenshots"
}

# Capture all locales
FAILED=()
for lang in "${LANGUAGES[@]}"; do
    if ! capture_locale "$lang"; then
        FAILED+=("$lang")
    fi
done

echo ""
echo "=========================================="
echo "  macOS Screenshot Capture Complete"
echo "=========================================="
for lang in "${LANGUAGES[@]}"; do
    dir="$SCREENSHOTS_DIR/$lang/macos"
    if [[ -d "$dir" ]]; then
        count=$(ls "$dir"/*.png 2>/dev/null | wc -l | tr -d ' ')
        echo "  $lang/macos: $count screenshots"
    fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️  Failed: ${FAILED[*]}"
fi

echo ""
echo "Done! Upload to App Store Connect under the macOS platform."
echo "If sidebar navigation failed, grant Accessibility permission to your terminal."
