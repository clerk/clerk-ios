#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift run NativeCoreProof
fixture=$(uuidgen)
executable=$(swift build --show-bin-path)/NativeCoreProof
trap '"$executable" --credential-upgrade cleanup "$fixture"' EXIT
for mode in seed restore restore clear assert-cleared; do
  "$executable" --credential-upgrade "$mode" "$fixture"
done
