#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "Usage: scripts/run-e2e-xcodebuild.sh <xcodebuild command...>" >&2
  exit 64
fi

attempts="${E2E_XCODEBUILD_ATTEMPTS:-1}"
if ! [[ "$attempts" =~ ^[0-9]+$ ]] || [[ "$attempts" -lt 1 ]]; then
  attempts=1
fi

log_path="${E2E_XCODEBUILD_LOG_PATH:-}"
if [[ -z "$log_path" ]]; then
  if [[ -n "${E2E_RESULT_BUNDLE_PATH:-}" ]]; then
    log_path="${E2E_RESULT_BUNDLE_PATH%.xcresult}.xcodebuild.log"
  else
    log_path="build/reports/E2EHost.xcodebuild.log"
  fi
fi

mkdir -p "$(dirname "$log_path")"

attempt_log_path() {
  local path="$1"
  local attempt="$2"
  local directory
  local filename

  directory="$(dirname "$path")"
  filename="$(basename "$path")"

  if [[ "$filename" == *.* ]]; then
    filename="${filename%.*}-attempt-${attempt}.${filename##*.}"
  else
    filename="${filename}-attempt-${attempt}"
  fi

  if [[ "$directory" == "." ]]; then
    printf "%s" "$filename"
  else
    printf "%s/%s" "$directory" "$filename"
  fi
}

log_has_test_assertion_failure() {
  local log_file="$1"

  grep -Eiq \
    "Test Case '.*' failed|Failing tests:|Assertion Failure:|XCTFail|XCTAssert" \
    "$log_file"
}

log_has_known_infrastructure_failure() {
  local log_file="$1"

  grep -Eiq \
    "Failed to start test runner|test runner failed to initialize|Test runner never began executing tests|Lost connection to test manager|Early unexpected exit.*bootstrapping|DTXProxyChannel|iOSSimulatorErrorDomain|CoreSimulator.*(failed|timed out|unavailable|crashed)|Timed out waiting for.*boot|Unable to boot|Failed to boot|Failed to install.*test runner|Failed to launch.*test runner|result bundle.*(failed|could not|unable)|Asynchronous wait failed: Exceeded timeout.*Backend API request|HTTP load failed.*error code: -1200|failed to connect 3:-9816" \
    "$log_file"
}

prepare_simulator_for_retry() {
  local simulator_id="${E2E_SIMULATOR_ID:-}"

  if [[ -z "$simulator_id" ]]; then
    return
  fi

  echo "Preparing simulator $simulator_id before retry."
  xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$simulator_id" -b >/dev/null 2>&1 || true
}

attempt=1
while true; do
  attempt_log="$(attempt_log_path "$log_path" "$attempt")"
  echo "Running E2E xcodebuild attempt $attempt/$attempts..."

  set +e
  "$@" 2>&1 | tee "$attempt_log"
  status=${PIPESTATUS[0]}
  set -e

  cp "$attempt_log" "$log_path"

  if [[ "$status" -eq 0 ]]; then
    exit 0
  fi

  if [[ "$attempt" -lt "$attempts" ]] &&
    log_has_known_infrastructure_failure "$attempt_log" &&
    ! log_has_test_assertion_failure "$attempt_log"; then
    echo "E2E xcodebuild failed with a known infrastructure signature; retrying."
    if [[ -n "${E2E_RESULT_BUNDLE_PATH:-}" ]]; then
      rm -rf "$E2E_RESULT_BUNDLE_PATH"
    fi
    prepare_simulator_for_retry
    attempt=$((attempt + 1))
    continue
  fi

  if [[ "$attempt" -lt "$attempts" ]]; then
    echo "E2E xcodebuild failed without a retryable infrastructure signature; not retrying."
  fi

  exit "$status"
done
