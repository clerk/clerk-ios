#!/bin/bash
set -euo pipefail

# Fetch integration test secrets from 1Password CLI
# This script is intended for Clerk employees who have access to the Shared vault.
# OSS contributors: This script will exit gracefully if 1Password CLI is not available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_FILE="$REPO_ROOT/.keys.json"
OP_SECRET_PATH="op://Shared/JS SDKs integration tests/add more/.keys.json"

# Check if 1Password CLI is installed
# Note: This should rarely happen since Makefile installs it automatically,
# but we check here as a safety net
if ! command -v op > /dev/null 2>&1; then
  echo "⚠️  1Password CLI is not installed. Skipping secret fetch."
  echo "   OSS contributors: This is expected. Integration tests will run in CI."
    echo "   Clerk employees: Run 'make fetch-test-keys' (it will auto-install the CLI)"
  exit 0
fi

# Try to fetch secrets from 1Password
echo "Fetching secrets from 1Password..."
TEMP_FILE=$(mktemp)
if op read "$OP_SECRET_PATH" > "$TEMP_FILE" 2>/dev/null; then
  # Check if jq is available (required for parsing nested JSON structure)
  if ! command -v jq > /dev/null 2>&1; then
    echo "❌ Error: jq is required to parse the 1Password JSON structure."
    echo "   Install jq via Homebrew: brew install jq"
    rm -f "$TEMP_FILE"
    exit 1
  fi

  # Copy the entire structure but only include pk (publishable key) in each sub-object
  if ! jq 'with_entries(.value = {pk: .value.pk})' "$TEMP_FILE" > "$KEYS_FILE" 2>/dev/null; then
    echo "❌ Error: Could not parse 1Password data as JSON."
    echo ""
    echo "   The 1Password secret at this path appears to be in an unexpected format."
    echo "   Please verify the 1Password path is correct and contains valid JSON data."
    echo ""
    echo "   Contact a team member if you need help accessing the correct secret."
    rm -f "$TEMP_FILE"
    exit 1
  fi

  if [ ! -s "$KEYS_FILE" ]; then
    echo "❌ Error: Generated .keys.json file is empty."
    rm -f "$TEMP_FILE"
    exit 1
  fi

  rm -f "$TEMP_FILE"
  echo "✅ Successfully fetched keys from 1Password and wrote to .keys.json"
  exit 0
else
  echo "⚠️  Could not fetch secrets from 1Password. This is expected for OSS contributors."
  echo "   Clerk employees: Ensure you have access to the Shared vault and CLI is authenticated."
  echo "   See https://developer.1password.com/docs/cli/get-started/#step-2-turn-on-the-1password-desktop-app-integration"
  rm -f "$TEMP_FILE"
  exit 0
fi

