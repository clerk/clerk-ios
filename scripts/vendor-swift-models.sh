#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
models_dest="$repo_root/Sources/ClerkSnapshots/Generated"
methods_dest="$repo_root/Sources/ClerkSnapshots/Generated/methods"
legacy_jscore_methods="$repo_root/Sources/ClerkJSCore/Generated/methods"
default_src="$repo_root/../clerk-js-ios-embed/packages/shared/generated/swift"

usage() {
  echo "Usage: $0 [JS_GENERATED_SWIFT_DIR]" >&2
  echo "Default: $default_src" >&2
  exit 2
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
fi

src="${1:-$default_src}"

if [ ! -d "$src" ]; then
  echo "ERROR: JS generated Swift dir not found: $src" >&2
  usage
fi

src="$(cd "$src" && pwd)"

if [ ! -d "$src/methods" ]; then
  echo "ERROR: $src has no methods/ directory." >&2
  exit 1
fi

if [ "$src" = "$models_dest" ] || [ "$src" = "$methods_dest" ] || [ "$src" = "$legacy_jscore_methods" ]; then
  echo "ERROR: source must be the JS generated/swift tree, not an iOS dest dir." >&2
  exit 1
fi

list_swift() {
  find "$1" -maxdepth 1 -type f -name '*.swift' | LC_ALL=C sort
}

write_if_changed() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm "$tmp"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$tmp" "$dest"
  chmod 644 "$dest"
  rm "$tmp"
}

prune_unexpected() {
  local dest_dir="$1"
  local expected="$2"
  local dest base

  [ -d "$dest_dir" ] || return 0

  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    base="$(basename "$dest")"
    if ! grep -Fxq "$base" "$expected"; then
      rm "$dest"
    fi
  done < <(list_swift "$dest_dir")
}

expected_models="$(mktemp)"
expected_methods="$(mktemp)"
trap 'rm -f "$expected_models" "$expected_methods"' EXIT

model_count=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  if grep -q '^import ClerkSnapshots$' "$file"; then
    echo "ERROR: model must not import ClerkSnapshots: $file" >&2
    exit 1
  fi
  basename "$file" >>"$expected_models"
  write_if_changed "$models_dest/$(basename "$file")" <"$file"
  model_count=$((model_count + 1))
done < <(list_swift "$src")

if [ "$model_count" -eq 0 ]; then
  echo "ERROR: no model .swift files in $src" >&2
  exit 1
fi

method_count=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  if grep -q '^import ClerkSnapshots$' "$file"; then
    echo "ERROR: method must not import ClerkSnapshots: $file" >&2
    exit 1
  fi
  basename "$file" >>"$expected_methods"
  write_if_changed "$methods_dest/$(basename "$file")" <"$file"
  method_count=$((method_count + 1))
done < <(list_swift "$src/methods")

prune_unexpected "$models_dest" "$expected_models"
prune_unexpected "$methods_dest" "$expected_methods"

if [ -d "$legacy_jscore_methods" ]; then
  find "$legacy_jscore_methods" -type f -name '*.swift' -delete
  rmdir "$legacy_jscore_methods" 2>/dev/null || true
fi

echo "Vendored $model_count models and $method_count methods from $src"
