#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ui_sources="Sources/ClerkKitUI"
clerk_sheet_file="$ui_sources/Extensions/View+ClerkSheet.swift"

failure_count=0

report_error() {
  local file="$1"
  local line="$2"
  local message="$3"

  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error file=%s,line=%s::%s\n' "$file" "$line" "$message"
  else
    printf 'error: %s:%s: %s\n' "$file" "$line" "$message" >&2
  fi

  failure_count=$((failure_count + 1))
}

scan_ui_sources_for() {
  local pattern="$1"

  grep -rnE --include='*.swift' "$pattern" "$ui_sources" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true
}

environment_object_pattern='@Environment\(([A-Za-z0-9_]+\.)*[A-Za-z0-9_]+(<[^>]*>)?\.self\)'
environment_type_capture='@Environment\((([A-Za-z0-9_]+\.)*[A-Za-z0-9_]+)(<[^>]*>)?\.self\)'
carried_types="$(grep -vE '^[[:space:]]*//' "$clerk_sheet_file" | grep -oE "$environment_object_pattern" | sed -E "s/$environment_type_capture/\1/" | sort -u)"

while IFS=: read -r file line match; do
  if [ -z "$file" ] || [ "$file" = "$clerk_sheet_file" ]; then
    continue
  fi

  type_name="$(printf '%s' "$match" | sed -E "s/.*$environment_type_capture.*/\1/")"
  if ! printf '%s\n' "$carried_types" | grep -qxF "$type_name"; then
    report_error "$file" "$line" "$type_name is read from the environment but ClerkUIContext in $clerk_sheet_file does not carry it, so sheets on Designed for iPad and Mac Catalyst won't receive it."
  fi
done < <(scan_ui_sources_for "$environment_object_pattern")

if [ "$failure_count" -gt 0 ]; then
  printf 'Clerk presentation check failed with %s issue(s).\n' "$failure_count" >&2
  exit 1
fi

printf 'Clerk presentation check passed: ClerkUIContext carries %s environment object types.\n' "$(printf '%s\n' "$carried_types" | wc -l | tr -d ' ')"
