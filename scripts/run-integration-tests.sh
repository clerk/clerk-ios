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

# Run each integration suite in a separate `swift test` invocation.
# Integration tests use shared singleton state and can interfere when suites run concurrently.
integration_suites=()
while IFS= read -r suite; do
  if [ -n "$suite" ]; then
    integration_suites+=("$suite")
  fi
done < <(
  grep -hE '^struct[[:space:]]+[A-Za-z0-9_]*IntegrationTests\b' "$REPO_ROOT"/Tests/Integration/*IntegrationTests.swift \
    | sed -E 's/^struct[[:space:]]+([A-Za-z0-9_]*IntegrationTests).*/\1/' \
    | sort -u
)

if [ "${#integration_suites[@]}" -eq 0 ]; then
  echo "❌ Error: No integration test suites found in Tests/Integration."
  exit 1
fi

echo "Discovered integration test suites: ${integration_suites[*]}"
echo ""

network_failure_pattern="NSURLErrorDomain Code=-(1001|1003|1004)|kCFErrorDomainCFNetwork Code=-(1001|1003|1004)|hostname could not be found|could not connect to the server|timed out"

run_suite_with_retries() {
  local suite="$1"
  local skip_build="$2"
  local max_attempts=3
  local attempt=1
  local log_file
  local status
  local -a swift_test_args

  while [ "$attempt" -le "$max_attempts" ]; do
    echo "Running integration suite '$suite' attempt $attempt/$max_attempts..."
    log_file="$(mktemp)"

    swift_test_args=(--filter "^ClerkKitTests\\.$suite/")
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
        echo "⚠️  Transient network/DNS failure detected for '$suite'. Retrying in ${sleep_seconds}s..."
        rm -f "$log_file"
        sleep "$sleep_seconds"
        attempt=$((attempt + 1))
        continue
      fi
    fi

    rm -f "$log_file"
    return "$status"
  done

  return 1
}

should_skip_build="false"
for suite in "${integration_suites[@]}"; do
  run_suite_with_retries "$suite" "$should_skip_build"
  should_skip_build="true"
done
