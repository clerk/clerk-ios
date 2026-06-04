#!/bin/bash

set -euo pipefail

failures=0

record_failure() {
  echo "ERROR: $*" >&2
  failures=1
}

require_value() {
  local name="$1"
  local value="$2"

  if [ -z "$value" ]; then
    record_failure "Could not read $name."
  fi
}

expect_equal() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$expected" != "$actual" ]; then
    record_failure "$name mismatch: expected '$expected', found '$actual'."
  fi
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$repo_root/Sources/ClerkKit/Utils/Version.swift"
readme_file="$repo_root/README.md"
contributing_file="$repo_root/CONTRIBUTING.md"
swiftformat_file="$repo_root/.swiftformat"

sdk_version="$(sed -nE 's/.*sdkVersion: String = "([^"]+)".*/\1/p' "$version_file")"
readme_xcode="$(sed -nE 's/^- Xcode ([0-9]+)\+$/\1/p' "$readme_file")"
contributing_xcode="$(sed -nE 's/^- macOS with Xcode ([0-9]+)\+ installed$/\1/p' "$contributing_file")"
readme_swift="$(sed -nE 's/^- Swift ([0-9]+(\.[0-9]+)?)\+$/\1/p' "$readme_file")"
contributing_swift="$(sed -nE 's/^- Swift ([0-9]+(\.[0-9]+)?)\+$/\1/p' "$contributing_file" | head -n 1)"
contributing_swiftformat="$(sed -nE 's/^- \*\*SwiftFormat parser version\*\*: ([0-9]+(\.[0-9]+)?)$/\1/p' "$contributing_file")"
swiftformat_swift="$(sed -nE 's/^--swiftversion ([0-9]+(\.[0-9]+)?)$/\1/p' "$swiftformat_file")"

require_value "Clerk.sdkVersion in $version_file" "$sdk_version"
require_value "Xcode requirement in $readme_file" "$readme_xcode"
require_value "Xcode requirement in $contributing_file" "$contributing_xcode"
require_value "Swift requirement in $readme_file" "$readme_swift"
require_value "Swift requirement in $contributing_file" "$contributing_swift"
require_value "SwiftFormat Swift version in $contributing_file" "$contributing_swiftformat"
require_value "SwiftFormat Swift version in $swiftformat_file" "$swiftformat_swift"

if [ -n "$sdk_version" ] && ! [[ "$sdk_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+(\.[0-9A-Za-z]+)*)?$ ]]; then
  record_failure "Clerk.sdkVersion must be SemVer, found '$sdk_version'."
fi

expect_equal "README/CONTRIBUTING Xcode requirement" "$readme_xcode" "$contributing_xcode"
expect_equal "README/CONTRIBUTING Swift requirement" "$readme_swift" "$contributing_swift"
expect_equal "CONTRIBUTING/.swiftformat SwiftFormat parser version" "$swiftformat_swift" "$contributing_swiftformat"

expected_runner_prefix="macos-$readme_xcode"
while IFS= read -r runner_label; do
  case "$runner_label" in
    "$expected_runner_prefix" | "$expected_runner_prefix-intel") ;;
    *) record_failure "Unexpected macOS runner '$runner_label'; expected '$expected_runner_prefix' or '$expected_runner_prefix-intel'." ;;
  esac
done < <(sed -nE 's/^[[:space:]]*runs-on: (macos-[^[:space:]]+)$/\1/p' "$repo_root"/.github/workflows/*.yml | sort -u)

if [ "$failures" -ne 0 ]; then
  exit 1
fi

echo "Version and toolchain declarations are consistent."
