#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${SWIFTLINT_VERSION:-0.63.2}"
install_root="${SWIFTLINT_INSTALL_DIR:-$repo_root/.tools/swiftlint/$version}"
bin_dir="$repo_root/.tools/bin"
binary_path="$install_root/swiftlint"
link_path="$bin_dir/swiftlint"

case "$(uname -s)" in
  Darwin)
    asset_name="portable_swiftlint.zip"
    asset_checksum="c59a405c85f95b92ced677a500804e081596a4cae4a6a485af76065557d6ed29"
    ;;
  Linux)
    case "$(uname -m)" in
      arm64 | aarch64)
        asset_name="swiftlint_linux_arm64.zip"
        asset_checksum="104dedff762157f5cff7752f1cc2a289b60f3ea677e72d651c6f3a3287fdd948"
        ;;
      x86_64 | amd64)
        asset_name="swiftlint_linux_amd64.zip"
        asset_checksum="dd1017cfd20a1457f264590bcb5875a6ee06cd75b9a9d4f77cd43a552499143b"
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

if [ -x "$binary_path" ] && [ "$("$binary_path" version)" = "$version" ]; then
  mkdir -p "$bin_dir"
  ln -sfn "../swiftlint/$version/swiftlint" "$link_path"
  echo "✅ SwiftLint $version installed"
  exit 0
fi

archive_url="https://github.com/realm/SwiftLint/releases/download/$version/$asset_name"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$install_root" "$bin_dir"
curl -fsSL "$archive_url" -o "$tmp_dir/$asset_name"
echo "$asset_checksum  $tmp_dir/$asset_name" | shasum -a 256 -c >/dev/null
unzip -oq "$tmp_dir/$asset_name" -d "$install_root"
chmod +x "$binary_path"
ln -sfn "../swiftlint/$version/swiftlint" "$link_path"

echo "✅ SwiftLint $version installed"
