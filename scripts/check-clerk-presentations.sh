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

while IFS=: read -r file line _; do
  if [ -z "$file" ]; then
    continue
  fi

  if [ "$file" != "$clerk_sheet_file" ]; then
    report_error "$file" "$line" "Present with clerkSheet instead so the presented content keeps the Clerk UI context on Designed for iPad and Mac Catalyst."
  fi
done < <(scan_ui_sources_for '\.sheet\(')

if [ "$failure_count" -gt 0 ]; then
  printf 'Clerk presentation check failed with %s issue(s).\n' "$failure_count" >&2
  exit 1
fi

clerk_sheet_count="$(scan_ui_sources_for '\.clerkSheet\(' | wc -l | tr -d ' ')"
printf 'Clerk presentation check passed: %s clerkSheet call sites.\n' "$clerk_sheet_count"
