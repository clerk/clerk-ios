#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DESTINATION="${IOS_SIMULATOR_DESTINATION:-}"
if [ -z "$DESTINATION" ]; then
  SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
candidates = [device for runtime, devices in json.load(sys.stdin)["devices"].items()
              if ".iOS-" in runtime for device in devices
              if device.get("isAvailable") and device["name"].startswith("iPhone")]
candidates.sort(key=lambda device: device["state"] != "Booted")
if not candidates:
    raise SystemExit("No available iPhone Simulator; set IOS_SIMULATOR_DESTINATION.")
print(candidates[0]["udid"])
')"
  DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
fi
case "$DESTINATION" in
  "platform=iOS Simulator,"*) ;;
  *) echo "AuthJourney requires an iOS Simulator destination." >&2; exit 1 ;;
esac

mkdir -p "$REPO_ROOT/.build/auth-journey-results"
OUTPUT="${CLERK_AUTH_JOURNEY_OUTPUT:-$(mktemp -d "$REPO_ROOT/.build/auth-journey-results/run.XXXXXX")}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
RESULT="$OUTPUT/result.xcresult"
if [ -e "$RESULT" ]; then
  echo "Refusing to reuse an existing result bundle: $RESULT" >&2
  exit 1
fi
DERIVED_DATA="${CLERK_AUTH_JOURNEY_DERIVED_DATA:-$REPO_ROOT/.build/auth-journey-build}"
echo "Running AuthJourney on $DESTINATION; evidence: $OUTPUT"
xcodebuild test \
  -project "$REPO_ROOT/Examples/AuthJourney/AuthJourney.xcodeproj" \
  -scheme AuthJourney -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO

xcrun xcresulttool get test-results tests --path "$RESULT" --compact > "$OUTPUT/tests.json"
xcrun xcresulttool get test-results summary --path "$RESULT" --compact > "$OUTPUT/summary.json"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUTPUT/attachments"
python3 "$SCRIPT_DIR/verify-auth-view-journey.py" "$OUTPUT"
