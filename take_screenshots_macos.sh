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

# Position, resize, and raise BarnHub window above all other apps
setup_window() {
    osascript -e "
    tell application \"BarnHub\" to activate
    delay 0.5
    tell application \"System Events\"
        tell process \"BarnHub\"
            set frontmost to true
            if (count of windows) > 0 then
                set position of first window to {100, 100}
                set size of first window to {$WINDOW_WIDTH, $WINDOW_HEIGHT}
                perform action \"AXRaise\" of first window
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

# Click at a position in the window (relative to window top-left, in points)
click_at() {
    local x="$1" y="$2"
    osascript -e "
    tell application \"BarnHub\" to activate
    tell application \"System Events\"
        tell process \"BarnHub\"
            set winPos to position of window 1
            set absX to (item 1 of winPos) + $x
            set absY to (item 2 of winPos) + $y
            click at {absX, absY}
        end tell
    end tell" 2>/dev/null || true
}

# Click first item in the detail list (to the right of sidebar, first row)
click_first_detail_row() {
    # Sidebar is ~80pt wide; title bar ~28pt; nav bar ~24pt; first row center ~65pt below nav
    click_at 200 100
}

# Go back via Cmd+[ keyboard shortcut
go_back() {
    osascript -e '
    tell application "BarnHub" to activate
    delay 0.3
    tell application "System Events"
        key code 33 using command down
    end tell' 2>/dev/null || true
}

# Take screenshot of BarnHub window
#
# Swift-based CGWindowListCopyWindowInfo requires Screen Recording permission
# for the invoking binary; `swift -e` does not inherit the terminal's grant,
# so it returns only the calling process's own windows (no BarnHub). That
# makes `screencapture -l <wid>` infeasible — fall back to region capture
# with a hard guarantee that BarnHub is frontmost (AXRaise) so no other
# app's window bleeds into the capture region.
capture_window() {
    local output_path="$1"
    osascript -e "
    tell application \"BarnHub\" to activate
    delay 0.2
    tell application \"System Events\"
        tell process \"BarnHub\"
            set frontmost to true
            if (count of windows) > 0 then
                perform action \"AXRaise\" of first window
            end if
        end tell
    end tell" 2>/dev/null || true
    sleep 0.6
    screencapture -R "100,100,${WINDOW_WIDTH},${WINDOW_HEIGHT}" -o -x "$output_path" 2>/dev/null
}

# Navigate the running BarnHub to a screenshot page, then capture.
# Sends a `barnhub://screenshot/<page>` URL event directly to the app via AppleScript
# (bypasses LaunchServices scheme registration — the event is delivered to the named
# target process and handled by .onOpenURL in ContentView).
capture_page() {
    local route="$1"
    local output="$2"
    osascript -e "tell application \"BarnHub\" to open location \"barnhub://screenshot/$route\"" 2>/dev/null || true
    sleep 1.5
    capture_window "$output"
}

# Capture screenshots for one language — 6 images showcasing 1.6 features.
# Single launch per locale: kill, launch once, navigate between pages via URL events,
# then kill at the end. ~6× faster than kill+relaunch per page.
capture_locale() {
    local lang="$1"
    local currency
    currency=$(currency_for_locale "$lang")
    local out_dir="$SCREENSHOTS_DIR/$lang/macos"
    mkdir -p "$out_dir"
    # Clear existing images so stale captures can't sneak into the App Store upload
    rm -f "$out_dir"/*.png

    echo "📸 Capturing $lang (currency: $currency)..."

    killall BarnHub 2>/dev/null || true
    sleep 1

    open "$APP_PATH" --args \
        -SeedSampleData \
        -ForceProMode \
        -net.shadowpuppet.BarnBook.hasCompletedFirstLaunch YES \
        -net.shadowpuppet.BarnBook.appLocale "$lang" \
        -net.shadowpuppet.BarnBook.currencyCode "$currency" \
        -net.shadowpuppet.BarnBook.appearanceMode 1 \
        -AppleLanguages "($lang)" \
        -AppleLocale "$lang"

    sleep 3
    setup_window
    sleep 1

    capture_page home            "$out_dir/01_home.png"
    capture_page horseDetail     "$out_dir/02_horse_detail.png"
    capture_page schedule        "$out_dir/03_schedule.png"
    capture_page feedProducts    "$out_dir/04_feed_products.png"
    capture_page dentistSchedule "$out_dir/05_dentist_schedule.png"
    capture_page accounting      "$out_dir/06_accounting.png"

    killall BarnHub 2>/dev/null || true
    sleep 1

    # macOS App Store requires exactly 1280x800, 1440x900, 2560x1600, or 2880x1800.
    # Captured region on 2× Retina lands a few pixels short (e.g. 2824x1764),
    # so resize to the nearest spec before upload.
    for f in "$out_dir"/*.png; do
        sips --resampleHeightWidth 1800 2880 "$f" --out "$f" >/dev/null 2>&1
    done

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
