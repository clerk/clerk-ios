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

# Run tests - each test method specifies which key to use from .keys.json
swift test --filter Integration

