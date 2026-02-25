#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/Examples"

created_count=0
existing_count=0

while IFS= read -r -d '' template_file; do
  local_secrets_file="${template_file%.template.plist}.plist"

  if [ -f "$local_secrets_file" ]; then
    existing_count=$((existing_count + 1))
    continue
  fi

  cp "$template_file" "$local_secrets_file"
  created_count=$((created_count + 1))
  echo "Created ${local_secrets_file#"$REPO_ROOT"/}"
done < <(find "$EXAMPLES_DIR" -name "LocalSecrets.template.plist" -print0)

echo "✅ Example LocalSecrets.plist setup complete (${created_count} created, ${existing_count} already present)"
