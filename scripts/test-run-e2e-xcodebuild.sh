#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$script_dir/run-e2e-xcodebuild.sh"
tmpdir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

assert_file_missing() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "expected file to be missing: $path"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  grep -Eq "$pattern" "$path" || fail "expected $path to contain pattern: $pattern"
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  [[ "$expected" == "$actual" ]] || fail "expected '$expected', got '$actual'"
}

write_fake_xcrun() {
  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/xcrun" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "${FAKE_XCRUN_LOG:?}"
exit 0
SH
  chmod +x "$tmpdir/bin/xcrun"
}

write_success_command() {
  local path="$1"
  cat > "$path" <<'SH'
#!/usr/bin/env bash
echo "xcodebuild completed"
exit 0
SH
  chmod +x "$path"
}

write_assertion_failure_command() {
  local path="$1"
  cat > "$path" <<'SH'
#!/usr/bin/env bash
count="$(cat "${FAKE_COUNTER:?}" 2>/dev/null || echo 0)"
count="$((count + 1))"
echo "$count" > "$FAKE_COUNTER"
echo "Assertion Failure: product assertion failed"
exit 42
SH
  chmod +x "$path"
}

write_infrastructure_flake_command() {
  local path="$1"
  cat > "$path" <<'SH'
#!/usr/bin/env bash
count="$(cat "${FAKE_COUNTER:?}" 2>/dev/null || echo 0)"
count="$((count + 1))"
echo "$count" > "$FAKE_COUNTER"

if [[ "$count" -eq 1 ]]; then
  echo "${FAKE_FAILURE_MESSAGE:-Lost connection to test manager}"
  exit 42
fi

echo "xcodebuild completed after retry"
exit 0
SH
  chmod +x "$path"
}

write_backend_api_infrastructure_flake_command() {
  local path="$1"
  cat > "$path" <<'SH'
#!/usr/bin/env bash
count="$(cat "${FAKE_COUNTER:?}" 2>/dev/null || echo 0)"
count="$((count + 1))"
echo "$count" > "$FAKE_COUNTER"

if [[ "$count" -eq 1 ]]; then
  echo "<unknown>:0: error: -[E2EHostE2ETests.E2EHostE2ETests testPhoneCodeSignUpThenPhoneCodeSignIn] : Asynchronous wait failed: Exceeded timeout of 30 seconds, with unfulfilled expectations: \"Backend API request\"."
  echo "Test Case '-[E2EHostE2ETests.E2EHostE2ETests testPhoneCodeSignUpThenPhoneCodeSignIn]' failed (31.334 seconds)."
  echo "Failing tests:"
  echo "HTTP load failed, 0/0 bytes (error code: -1200 [3:-9816])"
  exit 42
fi

echo "xcodebuild completed after backend API retry"
exit 0
SH
  chmod +x "$path"
}

write_persistent_infrastructure_failure_command() {
  local path="$1"
  cat > "$path" <<'SH'
#!/usr/bin/env bash
count="$(cat "${FAKE_COUNTER:?}" 2>/dev/null || echo 0)"
count="$((count + 1))"
echo "$count" > "$FAKE_COUNTER"
echo "CoreSimulator failed to boot"
exit 42
SH
  chmod +x "$path"
}

write_unclassified_failure_command() {
  local path="$1"
  cat > "$path" <<'SH'
#!/usr/bin/env bash
count="$(cat "${FAKE_COUNTER:?}" 2>/dev/null || echo 0)"
count="$((count + 1))"
echo "$count" > "$FAKE_COUNTER"
echo "The build failed for an unrelated reason"
exit 42
SH
  chmod +x "$path"
}

run_success_log_path_test() {
  local command="$tmpdir/success.sh"
  local output="$tmpdir/success.out"
  local log_path="$tmpdir/logs/E2EHost.xcodebuild.log"

  write_success_command "$command"

  env E2E_XCODEBUILD_LOG_PATH="$log_path" "$runner" "$command" > "$output" 2>&1

  assert_file_exists "$tmpdir/logs/E2EHost.xcodebuild-attempt-1.log"
  assert_file_exists "$log_path"
  assert_contains "$log_path" "xcodebuild completed"
}

run_success_log_path_without_extension_test() {
  local command="$tmpdir/success-no-extension.sh"
  local output="$tmpdir/success-no-extension.out"
  local log_path="$tmpdir/logs/E2EHost"

  write_success_command "$command"

  env E2E_XCODEBUILD_LOG_PATH="$log_path" "$runner" "$command" > "$output" 2>&1

  assert_file_exists "$tmpdir/logs/E2EHost-attempt-1"
  assert_file_exists "$log_path"
  assert_contains "$log_path" "xcodebuild completed"
}

run_success_log_path_with_dotted_directory_test() {
  local command="$tmpdir/success-dotted-directory.sh"
  local output="$tmpdir/success-dotted-directory.out"
  local log_path="$tmpdir/logs.v2/E2EHost"

  write_success_command "$command"

  env E2E_XCODEBUILD_LOG_PATH="$log_path" "$runner" "$command" > "$output" 2>&1

  assert_file_exists "$tmpdir/logs.v2/E2EHost-attempt-1"
  assert_file_missing "$tmpdir/logs-attempt-1.v2/E2EHost"
  assert_file_exists "$log_path"
  assert_contains "$log_path" "xcodebuild completed"
}

run_infrastructure_retry_test() {
  local command="$tmpdir/infra-flake.sh"
  local output="$tmpdir/infra-flake.out"
  local log_path="$tmpdir/logs/infra.log"
  local counter="$tmpdir/infra-counter"
  local xcrun_log="$tmpdir/xcrun.log"
  local result_bundle_path="$tmpdir/result.xcresult"

  write_fake_xcrun
  write_infrastructure_flake_command "$command"
  mkdir -p "$result_bundle_path"
  touch "$result_bundle_path/Info.plist"

  env \
    PATH="$tmpdir/bin:$PATH" \
    FAKE_COUNTER="$counter" \
    FAKE_XCRUN_LOG="$xcrun_log" \
    E2E_XCODEBUILD_ATTEMPTS=2 \
    E2E_XCODEBUILD_LOG_PATH="$log_path" \
    E2E_RESULT_BUNDLE_PATH="$result_bundle_path" \
    E2E_SIMULATOR_ID="SIM-123" \
    "$runner" "$command" > "$output" 2>&1

  assert_equals "2" "$(cat "$counter")"
  assert_contains "$output" "known infrastructure signature; retrying"
  assert_contains "$xcrun_log" "simctl shutdown SIM-123"
  assert_contains "$xcrun_log" "simctl boot SIM-123"
  assert_contains "$xcrun_log" "simctl bootstatus SIM-123 -b"
  assert_file_exists "$tmpdir/logs/infra-attempt-1.log"
  assert_file_exists "$tmpdir/logs/infra-attempt-2.log"
  assert_file_missing "$result_bundle_path"
}

run_infrastructure_signature_matrix_test() {
  local signatures=(
    "Failed to start test runner"
    "test runner failed to initialize"
    "Test runner never began executing tests"
    "Lost connection to test manager"
    "Early unexpected exit while bootstrapping"
    "DTXProxyChannel disconnected"
    "iOSSimulatorErrorDomain returned code 146"
    "CoreSimulator timed out"
    "CoreSimulator unavailable"
    "CoreSimulator crashed"
    "Timed out waiting for device to boot"
    "Unable to boot simulator"
    "Failed to boot simulator"
    "Failed to install XCTest test runner"
    "Failed to launch XCTest test runner"
    "result bundle could not be written"
    "result bundle unable to open"
    "Asynchronous wait failed: Exceeded timeout of 30 seconds, with unfulfilled expectations: \"Backend API request\"."
    "HTTP load failed, 0/0 bytes (error code: -1200 [3:-9816])"
    "Connection 1: failed to connect 3:-9816, reason -1"
  )
  local index=0

  for signature in "${signatures[@]}"; do
    index="$((index + 1))"
    local command="$tmpdir/infra-signature-$index.sh"
    local output="$tmpdir/infra-signature-$index.out"
    local counter="$tmpdir/infra-signature-$index-counter"

    write_infrastructure_flake_command "$command"

    env \
      FAKE_COUNTER="$counter" \
      FAKE_FAILURE_MESSAGE="$signature" \
      E2E_XCODEBUILD_ATTEMPTS=2 \
      E2E_XCODEBUILD_LOG_PATH="$tmpdir/logs/infra-signature-$index.log" \
      "$runner" "$command" > "$output" 2>&1

    assert_equals "2" "$(cat "$counter")"
    assert_contains "$output" "known infrastructure signature; retrying"
  done
}

run_backend_api_test_failure_retry_test() {
  local command="$tmpdir/backend-api-infra-flake.sh"
  local output="$tmpdir/backend-api-infra-flake.out"
  local counter="$tmpdir/backend-api-infra-counter"

  write_backend_api_infrastructure_flake_command "$command"

  env \
    FAKE_COUNTER="$counter" \
    E2E_XCODEBUILD_ATTEMPTS=2 \
    E2E_XCODEBUILD_LOG_PATH="$tmpdir/logs/backend-api-infra.log" \
    "$runner" "$command" > "$output" 2>&1

  assert_equals "2" "$(cat "$counter")"
  assert_contains "$output" "known infrastructure signature; retrying"
  assert_file_exists "$tmpdir/logs/backend-api-infra-attempt-2.log"
}

run_assertion_failure_no_retry_test() {
  local command="$tmpdir/assertion-failure.sh"
  local output="$tmpdir/assertion-failure.out"
  local counter="$tmpdir/assertion-counter"
  local status

  write_assertion_failure_command "$command"

  set +e
  env \
    FAKE_COUNTER="$counter" \
    E2E_XCODEBUILD_ATTEMPTS=2 \
    E2E_XCODEBUILD_LOG_PATH="$tmpdir/logs/assertion.log" \
    "$runner" "$command" > "$output" 2>&1
  status="$?"
  set -e

  assert_equals "42" "$status"
  assert_equals "1" "$(cat "$counter")"
  assert_contains "$output" "failed without a retryable infrastructure signature"
  assert_file_missing "$tmpdir/logs/assertion-attempt-2.log"
}

run_unclassified_failure_no_retry_test() {
  local command="$tmpdir/unclassified-failure.sh"
  local output="$tmpdir/unclassified-failure.out"
  local counter="$tmpdir/unclassified-counter"
  local status

  write_unclassified_failure_command "$command"

  set +e
  env \
    FAKE_COUNTER="$counter" \
    E2E_XCODEBUILD_ATTEMPTS=2 \
    E2E_XCODEBUILD_LOG_PATH="$tmpdir/logs/unclassified.log" \
    "$runner" "$command" > "$output" 2>&1
  status="$?"
  set -e

  assert_equals "42" "$status"
  assert_equals "1" "$(cat "$counter")"
  assert_contains "$output" "failed without a retryable infrastructure signature"
  assert_file_missing "$tmpdir/logs/unclassified-attempt-2.log"
}

run_invalid_attempts_fallback_test() {
  local command="$tmpdir/persistent-infra.sh"
  local output="$tmpdir/invalid-attempts.out"
  local counter="$tmpdir/invalid-attempts-counter"
  local status

  write_persistent_infrastructure_failure_command "$command"

  set +e
  env \
    FAKE_COUNTER="$counter" \
    E2E_XCODEBUILD_ATTEMPTS=invalid \
    E2E_XCODEBUILD_LOG_PATH="$tmpdir/logs/invalid.log" \
    "$runner" "$command" > "$output" 2>&1
  status="$?"
  set -e

  assert_equals "42" "$status"
  assert_equals "1" "$(cat "$counter")"
  assert_contains "$output" "Running E2E xcodebuild attempt 1/1"
  assert_file_missing "$tmpdir/logs/invalid-attempt-2.log"
}

run_success_log_path_test
run_success_log_path_without_extension_test
run_success_log_path_with_dotted_directory_test
run_infrastructure_retry_test
run_infrastructure_signature_matrix_test
run_backend_api_test_failure_retry_test
run_assertion_failure_no_retry_test
run_unclassified_failure_no_retry_test
run_invalid_attempts_fallback_test

echo "run-e2e-xcodebuild tests passed."
