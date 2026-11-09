#!/bin/bash
#
# take_screenshots_macos.sh — Capture macOS App Store screenshots for all languages.
#
# Quit BarnHub first: the script launches its own Debug copy (same bundle ID) with
# in-memory sample data, and refuses to run while another BarnHub is open.
#
# Prerequisites:
#   Your terminal app needs Screen Recording permission (System Settings → Privacy &
#   Security) to capture the app window. Accessibility isn't needed: the window is
#   sized through its saved frame, not System Events.
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
            echo "Requires Screen Recording permission for your terminal."
            exit 0
            ;;
        *) LANGUAGES+=("$arg") ;;
    esac
done
[[ ${#LANGUAGES[@]} -eq 0 ]] && LANGUAGES=("${ALL_LANGUAGES[@]}")

# macOS App Store sizes are 1280x800, 1440x900, 2560x1600 or 2880x1800 (16:10).
# The window is sized in points; on a 2x Retina screen a 1440x900 window captures
# at exactly 2880x1800. If the screen's visible area can't hold 1440x900, fall
# back to 1280x800 (2560x1600). Nothing is resampled, so nothing is stretched.
WINDOW_WIDTH=1440
WINDOW_HEIGHT=900

# Never quit or capture an open BarnHub: the Debug build shares its bundle ID,
# so an open BarnHub would receive our URL events and be quit by the script.
if pgrep -x BarnHub >/dev/null; then
    echo "❌ BarnHub is running. Quit it first; this script launches its own Debug copy."
    exit 1
fi

# Window helper (visible screen frame, CGWindowID by PID). Compiled, because
# `swift -e` doesn't inherit the terminal's Screen Recording grant.
WINDOW_INFO="$PROJECT_DIR/.build/window_info"
swiftc -O "$PROJECT_DIR/scripts/window_info.swift" -o "$WINDOW_INFO" || {
    echo "❌ Couldn't compile scripts/window_info.swift"
    exit 1
}

read -r VIS_X VIS_Y VIS_W VIS_H SCREEN_H < <("$WINDOW_INFO" visible)
if (( VIS_W < WINDOW_WIDTH || VIS_H < WINDOW_HEIGHT )); then
    WINDOW_WIDTH=1280
    WINDOW_HEIGHT=800
fi
if (( VIS_W < WINDOW_WIDTH || VIS_H < WINDOW_HEIGHT )); then
    echo "❌ Visible screen area ${VIS_W}x${VIS_H} pt can't hold a 1280x800 window."
    exit 1
fi
# Centered inside the visible frame (below the menu bar, above the Dock).
WINDOW_X=$(( VIS_X + (VIS_W - WINDOW_WIDTH) / 2 ))
WINDOW_Y=$(( VIS_Y + (VIS_H - WINDOW_HEIGHT) / 2 ))

# The window gets its size from its saved frame (AppKit's "x y w h" window frame then
# the screen's visible frame, bottom-left origin). The Debug build is unsandboxed, so
# this is its own preferences domain, not the App Store BarnHub's container; the
# previous value is put back when the script exits.
DEFAULTS_DOMAIN="net.shadowpuppet.BarnBook"
FRAME_KEY="NSWindow Frame main-AppWindow-1"
WINDOW_FRAME="$WINDOW_X $(( SCREEN_H - WINDOW_Y - WINDOW_HEIGHT )) $WINDOW_WIDTH $WINDOW_HEIGHT $VIS_X $(( SCREEN_H - VIS_Y - VIS_H )) $VIS_W $VIS_H "
SAVED_FRAME=$(defaults read "$DEFAULTS_DOMAIN" "$FRAME_KEY" 2>/dev/null || true)

echo "=========================================="
echo "  BarnHub macOS Screenshot Capture"
echo "=========================================="
echo "  Languages: ${LANGUAGES[*]}"
echo "  Window: ${WINDOW_WIDTH}x${WINDOW_HEIGHT} pt at ${WINDOW_X},${WINDOW_Y}"
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

APP_PID=""

# Quit only the copy this script launched.
quit_app() {
    if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID" 2>/dev/null || true
        for _ in {1..20}; do kill -0 "$APP_PID" 2>/dev/null || break; sleep 0.25; done
    fi
    APP_PID=""
}
restore_frame() {
    if [[ -n "$SAVED_FRAME" ]]; then
        defaults write "$DEFAULTS_DOMAIN" "$FRAME_KEY" "$SAVED_FRAME"
    else
        defaults delete "$DEFAULTS_DOMAIN" "$FRAME_KEY" 2>/dev/null || true
    fi
}
trap 'quit_app; restore_frame' EXIT

# Capture just the BarnHub window by its CGWindowID: `-l` grabs the window's own
# pixels, so the Dock, desktop and other windows can't appear, even if something
# covers it; `-o` drops the shadow. Fails if the window isn't exactly the size the
# App Store needs.
capture_window() {
    local output_path="$1"
    local info wid x y w h
    info=$("$WINDOW_INFO" window "$APP_PID") || { echo "   ❌ No BarnHub window found"; return 1; }
    read -r wid x y w h <<< "$info"
    if (( w != WINDOW_WIDTH || h != WINDOW_HEIGHT )); then
        echo "   ❌ Window is ${w}x${h} pt, expected ${WINDOW_WIDTH}x${WINDOW_HEIGHT}"
        return 1
    fi
    screencapture -l "$wid" -o -x "$output_path" && "$WINDOW_INFO" flatten "$output_path"
}

LAST_CAPTURE=""

# Navigate the running BarnHub to a screenshot page, then capture.
# Sends a `barnhub://screenshot/<page>` URL event to the app at $APP_PATH (by path,
# so it can never reach an installed BarnHub); .onOpenURL in ContentView handles it.
capture_page() {
    local route="$1"
    local output="$2"
    local attempt
    for attempt in 1 2 3; do
        # Activate first: a background app gets App Nap'd and lags behind the events.
        osascript -e "tell application \"$APP_PATH\"
            activate
            open location \"barnhub://screenshot/$route\"
        end tell" >/dev/null
        # ScreenshotRouter takes ~1.7s to settle (pop, switch section, push).
        sleep 3
        capture_window "$output" || return 1
        # A page identical to the previous one means the URL event was dropped.
        if [[ -z "$LAST_CAPTURE" ]] || ! cmp -s "$LAST_CAPTURE" "$output"; then
            LAST_CAPTURE="$output"
            return 0
        fi
        echo "   ↻ $route didn't open (attempt $attempt), retrying"
    done
    echo "   ❌ $route never opened"
    rm -f "$output"
    return 1
}

# Capture screenshots for one language — 6 images showcasing 1.6 features.
# Single launch per locale: launch once, navigate between pages via URL events,
# then quit at the end.
capture_locale() {
    local lang="$1"
    local currency
    currency=$(currency_for_locale "$lang")
    local out_dir="$SCREENSHOTS_DIR/$lang/macos"
    mkdir -p "$out_dir"
    # Clear existing images so stale captures can't sneak into the App Store upload
    rm -f "$out_dir"/*.png

    echo "📸 Capturing $lang (currency: $currency)..."

    if pgrep -x BarnHub >/dev/null; then
        echo "   ❌ Another BarnHub is running; not touching it"
        return 1
    fi

    # Rewritten per launch: the app saves its frame again when it quits.
    defaults write "$DEFAULTS_DOMAIN" "$FRAME_KEY" "$WINDOW_FRAME"

    open -n "$APP_PATH" --args \
        -ApplePersistenceIgnoreState YES \
        -NSAppSleepDisabled YES \
        -SeedSampleData \
        -ForceProMode \
        -net.shadowpuppet.BarnBook.hasCompletedFirstLaunch YES \
        -net.shadowpuppet.BarnBook.appLocale "$lang" \
        -net.shadowpuppet.BarnBook.currencyCode "$currency" \
        -net.shadowpuppet.BarnBook.appearanceMode 1 \
        -AppleLanguages "($lang)" \
        -AppleLocale "$lang"

    for _ in {1..40}; do
        APP_PID=$(pgrep -f "^$APP_PATH/Contents/MacOS/BarnHub" | head -1 || true)
        [[ -n "$APP_PID" ]] && break
        sleep 0.25
    done
    if [[ -z "$APP_PID" ]]; then
        echo "   ❌ BarnHub didn't launch"
        return 1
    fi

    sleep 4
    LAST_CAPTURE=""

    local ok=0
    capture_page home            "$out_dir/01_home.png" &&
    capture_page horseDetail     "$out_dir/02_horse_detail.png" &&
    capture_page schedule        "$out_dir/03_schedule.png" &&
    capture_page feedProducts    "$out_dir/04_feed_products.png" &&
    capture_page dentistSchedule "$out_dir/05_dentist_schedule.png" &&
    capture_page accounting      "$out_dir/06_accounting.png" || ok=1

    quit_app
    sleep 1

    local f size expected="$(( WINDOW_WIDTH * 2 ))x$(( WINDOW_HEIGHT * 2 ))"
    for f in "$out_dir"/*.png; do
        [[ -e "$f" ]] || continue
        size=$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')
        if [[ "$size" != "$expected" ]]; then
            echo "   ❌ $(basename "$f") is $size, expected $expected (is the display 2x Retina?)"
            ok=1
        fi
    done

    local count
    count=$(ls "$out_dir"/*.png 2>/dev/null | wc -l | tr -d ' ')
    echo "   $([[ $ok -eq 0 ]] && echo ✅ || echo ⚠️) $lang/macos: $count screenshots"
    return $ok
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
echo "If capture failed, check Screen Recording permission for your terminal."
