#!/bin/bash
set -euo pipefail

# Run integration tests
# Only Clerk employees can run integration tests locally (they have 1Password vault access)
# OSS contributors: Integration tests will run automatically in CI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_FILE="$REPO_ROOT/.keys.json"

echo "Running integration tests..."
echo "⚠️  Note: Integration tests require network access and a valid Clerk test instance"
echo "⚠️  Note: Only Clerk employees can run integration tests locally (requires 1Password vault access)"
echo ""

# Check if .keys.json exists (tests will read from it directly)
if [ ! -f "$KEYS_FILE" ]; then
  echo "⚠️  Warning: .keys.json file not found."
  echo "   Clerk employees: Run 'make fetch-test-keys' to populate .keys.json from 1Password"
  echo "   OSS contributors: Integration tests will run automatically in CI."
  echo "   Run 'make setup' to create .keys.json file."
fi

integration_suites=()
while IFS= read -r suite_name; do
  integration_suites+=("$suite_name")
done < <(
  find "$REPO_ROOT/Tests/Integration" -name '*IntegrationTests.swift' -print \
    | sed -E 's|.*/([^/]+)\.swift$|\1|' \
    | sort
)

if [ "${#integration_suites[@]}" -eq 0 ]; then
  echo "❌ Error: No integration test suites found in Tests/Integration."
  exit 1
fi

echo "Found ${#integration_suites[@]} integration test suite(s):"
printf '  - %s\n' "${integration_suites[@]}"
echo ""

network_failure_pattern="NSURLErrorDomain Code=-(1001|1003|1004)|kCFErrorDomainCFNetwork Code=-(1001|1003|1004)|hostname could not be found|could not connect to the server|timed out"

run_integration_tests_with_retries() {
  local suite_name="$1"
  local skip_build="$2"
  local max_attempts=3
  local attempt=1
  local integration_filter="^ClerkKitTests\\.${suite_name}/"
  local log_file
  local status
  local -a swift_test_args

  while [ "$attempt" -le "$max_attempts" ]; do
    echo "Running ${suite_name} attempt $attempt/$max_attempts..."
    log_file="$(mktemp)"

    swift_test_args=(--filter "$integration_filter")
    if [ "$skip_build" = "true" ]; then
      swift_test_args=(--skip-build "${swift_test_args[@]}")
    fi

    set +e
    swift test "${swift_test_args[@]}" 2>&1 | tee "$log_file"
    status="${PIPESTATUS[0]}"
    set -e

    if [ "$status" -eq 0 ]; then
      rm -f "$log_file"
      return 0
    fi

    if grep -Eq "$network_failure_pattern" "$log_file"; then
      if [ "$attempt" -lt "$max_attempts" ]; then
        sleep_seconds=$((attempt * 5))
        echo "⚠️  Transient network/DNS failure detected. Retrying in ${sleep_seconds}s..."
        rm -f "$log_file"
        sleep "$sleep_seconds"
        skip_build="true"
        attempt=$((attempt + 1))
        continue
      fi
    fi

    rm -f "$log_file"
    return "$status"
  done

  return 1
}

skip_build="false"
for suite_name in "${integration_suites[@]}"; do
  run_integration_tests_with_retries "$suite_name" "$skip_build"
  skip_build="true"
done
