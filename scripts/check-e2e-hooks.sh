#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

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

scan_sources_for() {
  local needle="$1"

  find Sources -type f -name '*.swift' -print0 | xargs -0 grep -nF "$needle" 2>/dev/null || true
}

is_allowed_e2e_usage_file() {
  case "$1" in
    Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOnePasswordView.swift | \
      Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCollectFieldView.swift | \
      Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView.swift | \
      Sources/ClerkKitUI/Extensions/View+HiddenTextField.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

reviewed_usage_count=0
expected_reviewed_usage_count=6

while IFS=: read -r file line _; do
  if [ -z "$file" ]; then
    continue
  fi

  if is_allowed_e2e_usage_file "$file"; then
    reviewed_usage_count=$((reviewed_usage_count + 1))
  else
    report_error "$file" "$line" "Unexpected ClerkE2EEnvironment usage. E2E hooks must stay limited to reviewed OS automation workarounds."
  fi
done < <(scan_sources_for "ClerkE2EEnvironment.isEnabled")

if [ "$reviewed_usage_count" -ne "$expected_reviewed_usage_count" ]; then
  report_error "scripts/check-e2e-hooks.sh" 1 "Expected $expected_reviewed_usage_count reviewed ClerkE2EEnvironment call sites, found $reviewed_usage_count. Update this allowlist only after reviewing the E2E-only behavior."
fi

while IFS=: read -r file line _; do
  if [ -z "$file" ]; then
    continue
  fi

  if [ "$file" != "Sources/ClerkKitUI/Common/ClerkE2EEnvironment.swift" ]; then
    report_error "$file" "$line" "Read CLERK_E2E_MODE through ClerkE2EEnvironment instead of directly accessing the environment."
  fi
done < <(scan_sources_for "CLERK_E2E_MODE")

while IFS=: read -r file line _; do
  if [ -z "$file" ]; then
    continue
  fi

  if [ "$file" != "Sources/ClerkKitUI/Common/ClerkE2EEnvironment.swift" ]; then
    report_error "$file" "$line" "Direct CLERK_E2E_MODE environment access is not allowed outside ClerkE2EEnvironment."
  fi
done < <(scan_sources_for 'ProcessInfo.processInfo.environment["CLERK_E2E_MODE"]')

if [ "$failure_count" -gt 0 ]; then
  printf 'E2E hook check failed with %s issue(s).\n' "$failure_count" >&2
  exit 1
fi

printf 'E2E hook check passed: %s reviewed call sites.\n' "$reviewed_usage_count"
