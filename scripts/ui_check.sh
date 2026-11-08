#!/bin/bash
#
# ui_check.sh — Pre-deploy UI check: opens every screen with sample data on
# iPhone, iPad and the Mac app, and fails if any screen crashes or doesn't show
# its content (ScreenWalkTests).
#
# Usage:
#   ./scripts/ui_check.sh                  # iPhone, iPad and Mac
#   ./scripts/ui_check.sh --iphone         # one platform (flags combine)
#   ./scripts/ui_check.sh --ipad --mac
#   ./scripts/ui_check.sh --only testHorseScreens   # one test method
#
# Simulators: IPHONE_SIM (default "iPhone 17") and IPAD_SIM (default: the first
# available "iPad Pro 13-inch", else any iPad) override the devices.
#
# Results go to .build/ui-check/<platform>.xcresult, with a screenshot of each
# failing screen. Open one with `open .build/ui-check/iphone.xcresult`.
#
# The Mac run drives the real app window, so leave the Mac alone while it runs.
# The test runner needs Accessibility access the first time (macOS asks).

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
PROJECT="BarnHub.xcodeproj"
OUT_DIR="$PROJECT_DIR/.build/ui-check"
DERIVED_DATA="$PROJECT_DIR/.build/UICheckDerivedData"
IPHONE_SIM="${IPHONE_SIM:-iPhone 17}"

PLATFORMS=()
ONLY=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --iphone) PLATFORMS+=(iphone); shift ;;
        --ipad)   PLATFORMS+=(ipad); shift ;;
        --mac)    PLATFORMS+=(mac); shift ;;
        --only)   ONLY="${2:?--only needs a test method name}"; shift 2 ;;
        -h|--help) sed -n '3,21p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1 (see --help)"; exit 2 ;;
    esac
done
[[ ${#PLATFORMS[@]} -eq 0 ]] && PLATFORMS=(iphone ipad mac)

if [[ -z "${IPAD_SIM:-}" ]]; then
    # Device lines look like "    iPad Pro 13-inch (M5) (<UDID>) (Shutdown)": keep the name.
    ipads=$(xcrun simctl list devices available 2>/dev/null | grep -E '^ +iPad' \
        | sed -E 's/^ +//; s/ \([0-9A-F-]{36}\).*$//')
    IPAD_SIM=$(echo "$ipads" | grep -m1 '^iPad Pro 13-inch')
    [[ -z "$IPAD_SIM" ]] && IPAD_SIM=$(echo "$ipads" | head -1)
fi

mkdir -p "$OUT_DIR"
RESULTS=()
FAILED=0

run() {
    local name="$1"; shift
    local bundle="$1"; shift
    local result="$OUT_DIR/$name.xcresult"
    local log="$OUT_DIR/$name.log"
    local filter="$bundle/ScreenWalkTests${ONLY:+/$ONLY}"
    rm -rf "$result"
    echo "▶︎ $name: running $filter"
    local start=$SECONDS
    xcodebuild test \
        -project "$PROJECT" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$result" \
        -only-testing:"$filter" \
        -parallel-testing-enabled NO \
        "$@" > "$log" 2>&1
    local status=$?
    local elapsed=$((SECONDS - start))
    if [[ $status -eq 0 ]]; then
        RESULTS+=("✅ $name passed (${elapsed}s)")
    else
        FAILED=1
        RESULTS+=("❌ $name FAILED (${elapsed}s) — see $result and $log")
        # The failing assertions, so the summary says which screens broke.
        grep -E "error: -\[|: error: |Test Case .* failed|didn't show|no longer running|no viewer|Quick Look|share sheet" "$log" \
            | grep -v "^\s*$" | sort -u | head -40 | sed 's/^/    /'
        if grep -q "Unable to find a device\|is not available" "$log"; then
            echo "    (simulator not found — set IPHONE_SIM / IPAD_SIM; available: xcrun simctl list devices available)"
        fi
    fi
}

for platform in "${PLATFORMS[@]}"; do
    case "$platform" in
        iphone)
            run iphone BarnHubUITests -scheme BarnHub \
                -destination "platform=iOS Simulator,name=$IPHONE_SIM" CODE_SIGNING_ALLOWED=NO ;;
        ipad)
            if [[ -z "$IPAD_SIM" ]]; then
                FAILED=1; RESULTS+=("❌ ipad: no iPad simulator found (set IPAD_SIM)"); continue
            fi
            run ipad BarnHubUITests -scheme BarnHub \
                -destination "platform=iOS Simulator,name=$IPAD_SIM" CODE_SIGNING_ALLOWED=NO ;;
        mac)
            if pgrep -xq BarnHub; then
                FAILED=1; RESULTS+=("❌ mac: quit BarnHub first (the tests launch their own copy)"); continue
            fi
            run mac BarnHubMacUITests -scheme BarnHubMacUITests \
                -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO ;;
    esac
done

echo ""
echo "UI check (iPhone: $IPHONE_SIM, iPad: ${IPAD_SIM:-none})"
printf '%s\n' "${RESULTS[@]}"
exit $FAILED
