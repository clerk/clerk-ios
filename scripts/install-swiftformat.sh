#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${SWIFTFORMAT_VERSION:-0.60.0}"
install_root="${SWIFTFORMAT_INSTALL_DIR:-$repo_root/.tools/swiftformat/$version}"
bin_dir="$repo_root/.tools/bin"
binary_path="$install_root/swiftformat"
link_path="$bin_dir/swiftformat"

case "$(uname -s)" in
  Darwin)
    asset_name="swiftformat.zip"
    asset_checksum="8fe9aaec033fc994cbf07366eeffad2963601d1a0e975474546a606ead6e5a39"
    ;;
  Linux)
    case "$(uname -m)" in
      arm64 | aarch64)
        asset_name="swiftformat_linux_aarch64.zip"
        asset_checksum="bf04f581f56436e17dc78b7d4ab5d6890a983a6a4ddf60156a8ea81e5d7cf7ce"
        ;;
      x86_64 | amd64)
        asset_name="swiftformat_linux.zip"
        asset_checksum="ec804d11366205f81ed278e852d615d9216f69c0f80fe79fe67791e65d46e01a"
        ;;
      *)
        echo "Unsupported Linux architecture: $(uname -m)" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported operating system: $(uname -s)" >&2
    exit 1
    ;;
esac

if [ -x "$binary_path" ] && [ "$("$binary_path" --version)" = "$version" ]; then
  mkdir -p "$bin_dir"
  ln -sfn "../swiftformat/$version/swiftformat" "$link_path"
  echo "✅ SwiftFormat $version installed"
  exit 0
fi

archive_url="https://github.com/nicklockwood/SwiftFormat/releases/download/$version/$asset_name"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$install_root" "$bin_dir"
curl -fsSL "$archive_url" -o "$tmp_dir/$asset_name"
echo "$asset_checksum  $tmp_dir/$asset_name" | shasum -a 256 -c >/dev/null
unzip -oq "$tmp_dir/$asset_name" -d "$install_root"
chmod +x "$binary_path"
ln -sfn "../swiftformat/$version/swiftformat" "$link_path"

echo "✅ SwiftFormat $version installed"
