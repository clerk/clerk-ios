#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ui_sources="Sources/ClerkKitUI"
clerk_sheet_file="$ui_sources/Extensions/View+ClerkSheet.swift"

# Keep the declaration and forwarding checks scoped to the context itself.
clerk_context_source="$(sed -n '/^struct ClerkUIContext:/,/^}/p' "$clerk_sheet_file" | sed '/^[[:space:]]*\/\//d')"
clerk_context_carry_source="$(printf '%s\n' "$clerk_context_source" | sed -n '/^  func carry(/,/^  }/p')"

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
done < <(scan_ui_sources_for '\.(sheet|fullScreenCover|popover)\(')

while IFS=: read -r file line content; do
  if [ -z "$file" ]; then
    continue
  fi

  observable_type="$(printf '%s\n' "$content" | sed -nE 's/.*@Environment\(([A-Za-z0-9_]+)\.self\).*/\1/p')"

  if ! printf '%s\n' "$clerk_context_source" | grep -qF "@Environment($observable_type.self)"; then
    report_error "$file" "$line" "$observable_type is read from the environment but ClerkUIContext does not carry it into sheets. Add it to $clerk_sheet_file."
  fi
done < <(scan_ui_sources_for '@Environment\([A-Za-z0-9_]+\.self\)')

while IFS=: read -r line content; do
  if [ -z "$line" ]; then
    continue
  fi

  property="$(printf '%s\n' "$content" | sed -nE 's/.*@Environment\([A-Za-z0-9_]+\.self\).*var ([A-Za-z0-9_]+).*/\1/p')"

  if ! printf '%s\n' "$clerk_context_carry_source" | grep -qE "\.environment\([[:space:]]*$property[[:space:]]*\)"; then
    report_error "$clerk_sheet_file" "$line" "ClerkUIContext reads $property but does not forward it. Add .environment($property) inside carry(into:)."
  fi
done < <(grep -nE '^[[:space:]]*@Environment\([A-Za-z0-9_]+\.self\)' "$clerk_sheet_file")

if [ "$failure_count" -gt 0 ]; then
  printf 'Clerk presentation check failed with %s issue(s).\n' "$failure_count" >&2
  exit 1
fi

clerk_sheet_count="$(scan_ui_sources_for '\.clerkSheet\(' | wc -l | tr -d ' ')"
printf 'Clerk presentation check passed: %s clerkSheet call sites.\n' "$clerk_sheet_count"
