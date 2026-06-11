#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_FILE="$REPO_ROOT/.keys.json"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-clerk/clerk-ios}"
SECRET_NAME="CLERK_TEST_KEYS_JSON"

if ! command -v jq > /dev/null 2>&1; then
  echo "❌ Error: jq is required to validate .keys.json."
  echo "   Install jq via Homebrew: brew install jq"
  exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
  echo "❌ Error: GitHub CLI is required to update $SECRET_NAME."
  echo "   Install gh via Homebrew: brew install gh"
  exit 1
fi

if ! gh auth status -h github.com --active > /dev/null 2>&1; then
  echo "❌ Error: GitHub CLI is not authenticated for github.com."
  echo "   Run: gh auth login -h github.com"
  exit 1
fi

if [ ! -f "$KEYS_FILE" ]; then
  echo "❌ Error: .keys.json was not found."
  echo "   Run: make fetch-test-keys"
  exit 1
fi

if ! jq -e 'type == "object" and all(.[]; (.pk | type == "string" and length > 0) and (.sk == null or (.sk | type == "string")))' "$KEYS_FILE" > /dev/null; then
  echo "❌ Error: .keys.json must be an object of entries shaped like { \"pk\": \"pk_test_...\" } with optional \"sk\" values."
  exit 1
fi

echo "Syncing test keys to GitHub Actions secret $SECRET_NAME for $GITHUB_REPOSITORY..."
echo "Key names:"
jq -r 'keys | sort | .[]' "$KEYS_FILE" | sed 's/^/  - /'

jq -c . "$KEYS_FILE" | gh secret set "$SECRET_NAME" --repo "$GITHUB_REPOSITORY"
echo "✅ Synced $SECRET_NAME from .keys.json"
