#!/bin/bash
set -euo pipefail

# Run integration tests with proper environment variable loading
# Only Clerk employees can run integration tests locally (they have 1Password vault access)
# OSS contributors: Integration tests will run automatically in CI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.local"

echo "Running integration tests..."
echo "⚠️  Note: Integration tests require network access and a valid Clerk test instance"
echo "⚠️  Note: Only Clerk employees can run integration tests locally (requires 1Password vault access)"
echo ""

# Check if key is set as environment variable
if [ -n "${CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY:-}" ]; then
  echo "Using CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY from environment variable"
  swift test --filter Integration
  exit 0
fi

# Check if .env.local file exists and load it
if [ -f "$ENV_FILE" ]; then
  echo "Loading CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY from .env.local file"
  # Export variables from .env.local (skip comments and empty lines)
  set -a
  source "$ENV_FILE"
  set +a

  # Check if key was loaded
  if [ -n "${CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY:-}" ]; then
    swift test --filter Integration
    exit 0
  fi
fi

# Key not found
echo "❌ Error: CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY not found."
echo ""
echo "   Only Clerk employees can run integration tests locally."
echo "   Clerk employees: Run 'make fetch-secrets' to populate .env.local from 1Password"
echo ""
echo "   OSS contributors: Integration tests will run automatically in CI."
echo "   Set it as an environment variable or add it to .env.local file."
echo "   Run 'make setup' to create .env.local file."
exit 1

