#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <publishable-key>"
  exit 1
fi

PUBLISHABLE_KEY="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/Examples"

updated_count=0

while IFS= read -r -d '' local_secrets_file; do
  /usr/bin/plutil -replace CLERK_PUBLISHABLE_KEY -string "$PUBLISHABLE_KEY" "$local_secrets_file"
  updated_count=$((updated_count + 1))
  echo "Updated ${local_secrets_file#"$REPO_ROOT"/}"
done < <(find "$EXAMPLES_DIR" -type f -name "LocalSecrets.plist" -print0)

if [ "$updated_count" -eq 0 ]; then
  echo "No LocalSecrets.plist files found under Examples"
  exit 1
fi

echo "✅ Updated CLERK_PUBLISHABLE_KEY in ${updated_count} example LocalSecrets.plist files"
