#!/bin/bash
set -euo pipefail

# Create .env.local file with blank integration test key if it doesn't exist
# This ensures setup works for both Clerk employees and OSS contributors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.local"

if [ ! -f "$ENV_FILE" ]; then
  echo "Creating .env.local file..."
  cat > "$ENV_FILE" << 'EOF'
# Integration Test Configuration
# Add your Clerk test instance publishable key below
#
# For Clerk employees: Run 'make fetch-secrets' to automatically populate this file from 1Password
# For OSS contributors: Integration tests will run automatically in CI
#
# Get the key from your Clerk Dashboard or ask a team member for the integration test instance key
CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY=
EOF
  echo "✅ Created .env.local file."
else
  echo "✅ .env.local file already exists."
fi

