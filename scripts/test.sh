#!/bin/bash
#
# test.sh — The full BarnHub test suite, as one command. deploy.sh and CI
# (.github/workflows/ci.yml) both run this, so a pass here means the same as a
# pass there.
#
#   unit    BarnHubTests (unit tests) on an iPhone simulator
#   iphone  ScreenWalkTests on iPhone: opens every screen with sample data and
#           fails if one crashes or doesn't show its content
#   ipad    ScreenWalkTests on iPad
#   mac     ScreenWalkTests on the native Mac app (BarnHubMacUITests). Opt-in:
#           it drives real windows on this Mac and, sharing the app's bundle ID,
#           would quit a BarnHub you have open, so it never runs by default.
#
# Usage:
#   ./scripts/test.sh                      # unit, iphone, ipad
#   ./scripts/test.sh --all                # those plus mac
#   ./scripts/test.sh --unit               # pick steps (flags combine)
#   ./scripts/test.sh --iphone --ipad --mac   # just the UI screen walk
#   ./scripts/test.sh --iphone --only testHorseScreens   # one UI test method
#
# Simulators: the newest installed iOS runtime's "iPhone 17" and
# "iPad Pro 13-inch (M5)" (or the closest match). Override the names with
# IPHONE_SIM / IPAD_SIM, and pin a runtime with SIM_OS (e.g. SIM_OS=26.5).
#
# Results go to .build/test-results/<step>.xcresult with a screenshot of each
# failing screen, and the full log beside it. `open` an .xcresult to look.
#
# The Mac step refuses to start while BarnHub is open. Leave the Mac alone while
# it runs; macOS asks for Accessibility access the first time.

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
PROJECT="BarnHub.xcodeproj"
OUT_DIR="$PROJECT_DIR/.build/test-results"
DERIVED_DATA="$PROJECT_DIR/.build/TestDerivedData"

STEPS=()
ONLY=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --unit)   STEPS+=(unit); shift ;;
        --iphone) STEPS+=(iphone); shift ;;
        --ipad)   STEPS+=(ipad); shift ;;
        --mac)    STEPS+=(mac); shift ;;
        --all)    STEPS+=(unit iphone ipad mac); shift ;;
        --only)   ONLY="${2:?--only needs a test method name}"; shift 2 ;;
        -h|--help) sed -n '3,31p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1 (see --help)"; exit 2 ;;
    esac
done
[[ ${#STEPS[@]} -eq 0 ]] && STEPS=(unit iphone ipad)

# Prints "<name>|<udid>|<os>" for the best available simulator: an exact name
# match on the newest runtime (or SIM_OS), else the first device of that family.
find_simulator() {
    local wanted="$1" family="$2"
    xcrun simctl list devices available -j | WANTED="$wanted" FAMILY="$family" \
        SIM_OS="${SIM_OS:-}" python3 -c '
import json, os, sys
data = json.load(sys.stdin)["devices"]
wanted, family, pin = os.environ["WANTED"], os.environ["FAMILY"], os.environ["SIM_OS"]
def version(rt):
    try: return tuple(int(p) for p in rt.rsplit("iOS-", 1)[1].split("-"))
    except (IndexError, ValueError): return ()
runtimes = sorted((rt for rt in data if "SimRuntime.iOS-" in rt), key=version, reverse=True)
if pin:
    runtimes = [rt for rt in runtimes if ".".join(map(str, version(rt))).startswith(pin)]
for match in (lambda n: n == wanted, lambda n: n.startswith(wanted), lambda n: n.startswith(family)):
    for rt in runtimes:
        for d in data[rt]:
            if d.get("isAvailable") and match(d["name"]):
                print("|".join([d["name"], d["udid"], ".".join(map(str, version(rt)))]))
                sys.exit(0)
sys.exit(1)
'
}

IPHONE=$(find_simulator "${IPHONE_SIM:-iPhone 17}" iPhone || true)
IPAD=$(find_simulator "${IPAD_SIM:-iPad Pro 13-inch (M5)}" iPad || true)
describe() { [[ -n "$1" ]] && echo "${1%%|*} (iOS ${1##*|})" || echo "none found"; }
udid() { cut -d'|' -f2 <<<"$1"; }

mkdir -p "$OUT_DIR"
RESULTS=()
FAILED=0

run() {
    local step="$1" filter="$2"; shift 2
    local result="$OUT_DIR/$step.xcresult" log="$OUT_DIR/$step.log"
    rm -rf "$result"
    echo "▶︎ $step: $filter"
    local start=$SECONDS
    xcodebuild test \
        -project "$PROJECT" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$result" \
        -only-testing:"$filter" \
        -parallel-testing-enabled NO \
        -destination-timeout 120 \
        "$@" > "$log" 2>&1
    local status=$? elapsed=$((SECONDS - start))
    if [[ $status -eq 0 ]]; then
        RESULTS+=("✅ $step passed (${elapsed}s)")
        echo "   passed (${elapsed}s)"
    else
        FAILED=1
        RESULTS+=("❌ $step FAILED (${elapsed}s): $result")
        echo "   FAILED (${elapsed}s), log: $log"
        # The failing assertions, so the output says which tests or screens broke.
        grep -E ": error: |error: -\[|\*\* TEST FAILED|\*\* BUILD FAILED" "$log" \
            | sort -u | head -60 | sed 's/^/    /'
    fi
}

ui_filter() { echo "$1/ScreenWalkTests${ONLY:+/$ONLY}"; }

for step in "${STEPS[@]}"; do
    case "$step" in
        unit)
            [[ -z "$IPHONE" ]] && { FAILED=1; RESULTS+=("❌ unit: no iPhone simulator"); continue; }
            run unit BarnHubTests -scheme BarnHub \
                -destination "platform=iOS Simulator,id=$(udid "$IPHONE")" CODE_SIGNING_ALLOWED=NO ;;
        iphone)
            [[ -z "$IPHONE" ]] && { FAILED=1; RESULTS+=("❌ iphone: no iPhone simulator"); continue; }
            run iphone "$(ui_filter BarnHubUITests)" -scheme BarnHub \
                -destination "platform=iOS Simulator,id=$(udid "$IPHONE")" CODE_SIGNING_ALLOWED=NO ;;
        ipad)
            [[ -z "$IPAD" ]] && { FAILED=1; RESULTS+=("❌ ipad: no iPad simulator"); continue; }
            run ipad "$(ui_filter BarnHubUITests)" -scheme BarnHub \
                -destination "platform=iOS Simulator,id=$(udid "$IPAD")" CODE_SIGNING_ALLOWED=NO ;;
        mac)
            # Only the Mac app: simulator copies of BarnHub don't count.
            if ps -axo command= | grep -q '/BarnHub\.app/Contents/MacOS/BarnHub'; then
                FAILED=1; RESULTS+=("❌ mac: quit BarnHub first (the tests launch their own copy)"); continue
            fi
            # Ad-hoc signed without entitlements: an unsigned test runner is
            # "damaged" to Gatekeeper, and the app's iCloud entitlements need a
            # profile. The tests use an in-memory store, so they need neither.
            run mac "$(ui_filter BarnHubMacUITests)" -scheme BarnHubMacUITests \
                -destination "platform=macOS" \
                CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
                PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS= ;;
    esac
done

echo ""
echo "BarnHub tests (iPhone: $(describe "$IPHONE"), iPad: $(describe "$IPAD"))"
printf '%s\n' "${RESULTS[@]}"
exit $FAILED
