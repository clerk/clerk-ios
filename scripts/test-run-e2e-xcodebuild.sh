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
  echo "Lost connection to test manager"
  exit 42
fi

echo "xcodebuild completed after retry"
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

run_infrastructure_retry_test() {
  local command="$tmpdir/infra-flake.sh"
  local output="$tmpdir/infra-flake.out"
  local log_path="$tmpdir/logs/infra.log"
  local counter="$tmpdir/infra-counter"
  local xcrun_log="$tmpdir/xcrun.log"

  write_fake_xcrun
  write_infrastructure_flake_command "$command"

  env \
    PATH="$tmpdir/bin:$PATH" \
    FAKE_COUNTER="$counter" \
    FAKE_XCRUN_LOG="$xcrun_log" \
    E2E_XCODEBUILD_ATTEMPTS=2 \
    E2E_XCODEBUILD_LOG_PATH="$log_path" \
    E2E_RESULT_BUNDLE_PATH="$tmpdir/result.xcresult" \
    E2E_SIMULATOR_ID="SIM-123" \
    "$runner" "$command" > "$output" 2>&1

  assert_equals "2" "$(cat "$counter")"
  assert_contains "$output" "known infrastructure signature; retrying"
  assert_contains "$xcrun_log" "simctl shutdown SIM-123"
  assert_contains "$xcrun_log" "simctl boot SIM-123"
  assert_contains "$xcrun_log" "simctl bootstatus SIM-123 -b"
  assert_file_exists "$tmpdir/logs/infra-attempt-1.log"
  assert_file_exists "$tmpdir/logs/infra-attempt-2.log"
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
run_infrastructure_retry_test
run_assertion_failure_no_retry_test
run_invalid_attempts_fallback_test

echo "run-e2e-xcodebuild tests passed."
