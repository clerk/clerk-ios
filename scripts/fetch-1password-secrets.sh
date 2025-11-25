#!/bin/bash
set -euo pipefail

# Fetch integration test secrets from 1Password CLI
# This script is intended for Clerk employees who have access to the Shared vault.
# OSS contributors: This script will exit gracefully if 1Password CLI is not available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.local"
OP_SECRET_PATH="op://Shared/JS SDKs integration tests/add more/.env.local"

# Check if 1Password CLI is installed
# Note: This should rarely happen since Makefile installs it automatically,
# but we check here as a safety net
if ! command -v op > /dev/null 2>&1; then
  echo "⚠️  1Password CLI is not installed. Skipping secret fetch."
  echo "   OSS contributors: This is expected. Integration tests will run in CI."
  echo "   Clerk employees: Run 'make fetch-secrets' (it will auto-install the CLI)"
  exit 0
fi

# Try to fetch secrets from 1Password
echo "Fetching secrets from 1Password..."
if op read "$OP_SECRET_PATH" > "$ENV_FILE" 2>/dev/null; then
  echo "✅ Successfully fetched secrets from 1Password and wrote to .env.local"
  exit 0
else
  echo "⚠️  Could not fetch secrets from 1Password. This is expected for OSS contributors."
  echo "   Clerk employees: Ensure you have access to the Shared vault and CLI is authenticated."
  echo "   See https://developer.1password.com/docs/cli/get-started/#step-2-turn-on-the-1password-desktop-app-integration"
  # Remove the file if it was created but empty
  [ -f "$ENV_FILE" ] && [ ! -s "$ENV_FILE" ] && rm -f "$ENV_FILE"
  exit 0
fi

