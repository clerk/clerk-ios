#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:-$PWD/.build/native-core-benchmark.json}"
swift build -c release --product NativeCoreProof
executable=$(swift build -c release --show-bin-path)/NativeCoreProof
/usr/bin/time -l "$executable" --benchmark "$output"
