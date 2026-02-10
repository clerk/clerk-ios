#!/bin/bash
set -euo pipefail

# Create .keys.json file with blank integration test key if it doesn't exist
# This ensures setup works for both Clerk employees and OSS contributors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_FILE="$REPO_ROOT/.keys.json"

if [ ! -f "$KEYS_FILE" ]; then
  echo "Creating .keys.json file..."
  cat > "$KEYS_FILE" << 'EOF'
{
  "with-email-codes": {
    "pk": ""
  }
}
EOF
fi
echo "✅ .keys.json installed"
