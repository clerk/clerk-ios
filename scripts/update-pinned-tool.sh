#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tool="${1:-}"

if [ -z "$tool" ]; then
  echo "Usage: $0 <swiftformat|swiftlint>" >&2
  exit 1
fi

case "$tool" in
  swiftformat)
    repo="nicklockwood/SwiftFormat"
    install_script="$repo_root/scripts/install-swiftformat.sh"
    docs_label="SwiftFormat"
    assets=(
      "swiftformat.zip"
      "swiftformat_linux.zip"
      "swiftformat_linux_aarch64.zip"
    )
    ;;
  swiftlint)
    repo="realm/SwiftLint"
    install_script="$repo_root/scripts/install-swiftlint.sh"
    docs_label="SwiftLint"
    assets=(
      "portable_swiftlint.zip"
      "swiftlint_linux_amd64.zip"
      "swiftlint_linux_arm64.zip"
    )
    ;;
  *)
    echo "Unsupported tool: $tool" >&2
    exit 1
    ;;
esac

release_json="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")"

RELEASE_JSON="$release_json" \
INSTALL_SCRIPT="$install_script" \
CONTRIBUTING_PATH="$repo_root/CONTRIBUTING.md" \
DOCS_LABEL="$docs_label" \
ASSET_NAMES="$(printf '%s\n' "${assets[@]}")" \
ruby <<'RUBY'
require "json"

release = JSON.parse(ENV.fetch("RELEASE_JSON"))
install_script_path = ENV.fetch("INSTALL_SCRIPT")
contributing_path = ENV.fetch("CONTRIBUTING_PATH")
docs_label = ENV.fetch("DOCS_LABEL")
asset_names = ENV.fetch("ASSET_NAMES").lines(chomp: true)

version = release.fetch("tag_name")
assets_by_name = release.fetch("assets").each_with_object({}) do |asset, map|
  map[asset.fetch("name")] = asset
end

missing_assets = asset_names.reject { |name| assets_by_name.key?(name) }
unless missing_assets.empty?
  abort("Missing expected release assets for #{version}: #{missing_assets.join(', ')}")
end

checksums = asset_names.to_h do |name|
  digest = assets_by_name.fetch(name).fetch("digest")
  checksum = digest.sub(/\Asha256:/, "")
  [name, checksum]
end

install_script = File.read(install_script_path)

checksums.each_value do |checksum|
  unless checksum.match?(/\A[0-9a-f]{64}\z/)
    abort("Invalid sha256 digest for #{version}")
  end
end

case docs_label
when "SwiftFormat"
  abort("Could not update SwiftFormat version") unless install_script.sub!(
    /version="\$\{SWIFTFORMAT_VERSION:-[^"]+\}"/,
    %{version="${SWIFTFORMAT_VERSION:-#{version}}"}
  )
  abort("Could not update SwiftFormat Darwin checksum") unless install_script.sub!(
    /asset_name="swiftformat\.zip"\n    asset_checksum="[0-9a-f]+"/,
    %{asset_name="swiftformat.zip"\n    asset_checksum="#{checksums.fetch("swiftformat.zip")}"} 
  )
  abort("Could not update SwiftFormat Linux ARM64 checksum") unless install_script.sub!(
    /asset_name="swiftformat_linux_aarch64\.zip"\n        asset_checksum="[0-9a-f]+"/,
    %{asset_name="swiftformat_linux_aarch64.zip"\n        asset_checksum="#{checksums.fetch("swiftformat_linux_aarch64.zip")}"} 
  )
  abort("Could not update SwiftFormat Linux AMD64 checksum") unless install_script.sub!(
    /asset_name="swiftformat_linux\.zip"\n        asset_checksum="[0-9a-f]+"/,
    %{asset_name="swiftformat_linux.zip"\n        asset_checksum="#{checksums.fetch("swiftformat_linux.zip")}"} 
  )
when "SwiftLint"
  abort("Could not update SwiftLint version") unless install_script.sub!(
    /version="\$\{SWIFTLINT_VERSION:-[^"]+\}"/,
    %{version="${SWIFTLINT_VERSION:-#{version}}"}
  )
  abort("Could not update SwiftLint Darwin checksum") unless install_script.sub!(
    /asset_name="portable_swiftlint\.zip"\n    asset_checksum="[0-9a-f]+"/,
    %{asset_name="portable_swiftlint.zip"\n    asset_checksum="#{checksums.fetch("portable_swiftlint.zip")}"} 
  )
  abort("Could not update SwiftLint Linux ARM64 checksum") unless install_script.sub!(
    /asset_name="swiftlint_linux_arm64\.zip"\n        asset_checksum="[0-9a-f]+"/,
    %{asset_name="swiftlint_linux_arm64.zip"\n        asset_checksum="#{checksums.fetch("swiftlint_linux_arm64.zip")}"} 
  )
  abort("Could not update SwiftLint Linux AMD64 checksum") unless install_script.sub!(
    /asset_name="swiftlint_linux_amd64\.zip"\n        asset_checksum="[0-9a-f]+"/,
    %{asset_name="swiftlint_linux_amd64.zip"\n        asset_checksum="#{checksums.fetch("swiftlint_linux_amd64.zip")}"} 
  )
else
  abort("Unsupported docs label: #{docs_label}")
end

File.write(install_script_path, install_script)

contributing = File.read(contributing_path)
heading = "## Code #{docs_label == 'SwiftFormat' ? 'Formatting' : 'Linting'}"
pattern = /(#{Regexp.escape(heading)}.*?- \*\*Pinned version\*\*: )`[^`]+`/m

unless contributing.match?(pattern)
  abort("Could not find pinned version entry for #{docs_label} in CONTRIBUTING.md")
end

contributing.sub!(pattern, "\\1`#{version}`")
File.write(contributing_path, contributing)

puts "Updated #{docs_label} pin to #{version}"
checksums.each do |name, checksum|
  puts "  #{name}: #{checksum}"
end
RUBY
