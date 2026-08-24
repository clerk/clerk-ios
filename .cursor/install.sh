#!/usr/bin/env bash
# Cursor Cloud Agent setup for the Clerk multi-repo workspace.
#
# Primary repo: clerk-ios (Swift). Sibling repos (checked out next to it via
# repositoryDependencies): clerk-android (Kotlin/Gradle) and javascript (@clerk/expo).
#
# This script is idempotent: every toolchain install is guarded so re-runs against
# a warm snapshot are fast. It installs the toolchains that run on Linux and refreshes
# each repo's dependencies. iOS build/test require macOS + Xcode and are not possible
# here; on Linux the runnable iOS dev loop is `make check` (SwiftFormat + SwiftLint).
set -euo pipefail

# --- Pinned versions -------------------------------------------------------
JDK_TARGET_PKG="openjdk-17-jdk-headless"          # Gradle runs on JDK 21, compiles with the 17 toolchain
NODE_VERSION="24.15.0"                              # javascript monorepo engines: node >=24.15
SWIFT_VERSION="6.2"                                 # provides sourcekit for SwiftLint on Linux
SWIFT_DIR="/opt/swift"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/sdk}"
ANDROID_CMDLINE_BUILD="9862592"                     # bootstrap command-line tools build
ANDROID_PLATFORM="android-36"
ANDROID_BUILD_TOOLS="36.0.0"

# --- Locate repos ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# Find a sibling repo by name + a marker file, searching the layouts a Cloud
# Agent might use (repositoryDependencies land next to the primary /workspace
# checkout, but exact roots vary, so probe several candidates).
locate_repo() {
  local name="$1" marker="$2" root
  for root in "$(dirname "$IOS_REPO")" "$HOME/repos" "$HOME" /agent/repos \
              "$(dirname "${WORKSPACE_ROOT:-/workspace}")" /workspace /workspaces; do
    if [ -n "$root" ] && [ -f "$root/$name/$marker" ]; then
      printf '%s' "$root/$name"
      return 0
    fi
  done
  return 1
}

ANDROID_REPO="$(locate_repo clerk-android settings.gradle.kts || true)"
JS_REPO="$(locate_repo javascript pnpm-workspace.yaml || true)"

# --- System packages -------------------------------------------------------
install_apt_packages() {
  local pkgs=("$JDK_TARGET_PKG" ruby unzip zip
    binutils libc6-dev libcurl4-openssl-dev libedit2 libpython3-dev
    libstdc++-13-dev libxml2-dev libz3-dev pkg-config tzdata zlib1g-dev
    libncurses-dev libsqlite3-0 libtinfo6)
  local missing=()
  for p in "${pkgs[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    log "System packages already installed"
    return
  fi
  log "Installing system packages: ${missing[*]}"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
}

# --- Swift toolchain (SwiftLint sourcekit + SwiftFormat host) --------------
install_swift() {
  if [ -x "$SWIFT_DIR/usr/bin/swift" ]; then
    log "Swift toolchain already present ($("$SWIFT_DIR/usr/bin/swift" --version | head -1))"
    return
  fi
  log "Installing Swift $SWIFT_VERSION toolchain"
  local url="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/swift.tar.gz" "$url"
  sudo mkdir -p "$SWIFT_DIR"
  sudo tar -xzf "$tmp/swift.tar.gz" -C "$SWIFT_DIR" --strip-components=1
  rm -rf "$tmp"
}

# --- Android SDK -----------------------------------------------------------
install_android_sdk() {
  local sdkmanager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
  if [ ! -x "$sdkmanager" ]; then
    log "Installing Android command-line tools"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/cmdline-tools.zip" \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_BUILD}_latest.zip"
    unzip -oq "$tmp/cmdline-tools.zip" -d "$ANDROID_HOME/cmdline-tools"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf "$tmp"
  fi
  local java21; java21="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  export JAVA_HOME="${JAVA_HOME:-$java21}"
  if [ -d "$ANDROID_HOME/platforms/$ANDROID_PLATFORM" ] \
     && [ -d "$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS" ] \
     && [ -d "$ANDROID_HOME/platform-tools" ]; then
    log "Android SDK packages already installed"
    return
  fi
  log "Installing Android SDK packages ($ANDROID_PLATFORM, build-tools $ANDROID_BUILD_TOOLS)"
  yes | "$sdkmanager" --licenses >/dev/null 2>&1 || true
  "$sdkmanager" --install "platform-tools" "platforms;$ANDROID_PLATFORM" "build-tools;$ANDROID_BUILD_TOOLS" >/dev/null
  yes | "$sdkmanager" --licenses >/dev/null 2>&1 || true
}

# --- Node 24 via nvm -------------------------------------------------------
install_node() {
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    log "Installing nvm"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  if [ ! -d "$NVM_DIR/versions/node/v$NODE_VERSION" ]; then
    log "Installing Node $NODE_VERSION"
    nvm install "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
  else
    log "Node $NODE_VERSION already installed"
  fi
  corepack enable >/dev/null 2>&1 || true
}

# --- Shell environment for interactive agent shells ------------------------
write_shell_env() {
  local marker_begin="# >>> clerk multi-repo cloud env >>>"
  local marker_end="# <<< clerk multi-repo cloud env <<<"
  local bashrc="$HOME/.bashrc"
  local java_home; java_home="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  touch "$bashrc"
  # Remove any previous block, then append a fresh one.
  if grep -qF "$marker_begin" "$bashrc"; then
    awk -v b="$marker_begin" -v e="$marker_end" '
      $0==b {skip=1} !skip {print} $0==e {skip=0}' "$bashrc" > "$bashrc.tmp"
    mv "$bashrc.tmp" "$bashrc"
  fi
  log "Writing shell environment block to ~/.bashrc"
  cat >> "$bashrc" <<EOF
$marker_begin
# Java: Gradle runs on the system JDK (21); the Android build uses the 17 toolchain automatically.
export JAVA_HOME="$java_home"
# Android SDK
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH"
# Swift (SwiftFormat/SwiftLint on Linux); sourcekit needs LD_LIBRARY_PATH
export PATH="$SWIFT_DIR/usr/bin:\$PATH"
export LD_LIBRARY_PATH="$SWIFT_DIR/usr/lib/swift/linux:\${LD_LIBRARY_PATH:-}"
# Node 24 (javascript monorepo) ahead of the system node
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
if [ -d "\$NVM_DIR/versions/node/v$NODE_VERSION/bin" ]; then
  export PATH="\$NVM_DIR/versions/node/v$NODE_VERSION/bin:\$PATH"
fi
$marker_end
EOF
}

# --- Per-repo dependency refresh ------------------------------------------
setup_ios() {
  [ -d "$IOS_REPO" ] || { log "clerk-ios missing, skipping"; return; }
  log "clerk-ios: installing SwiftFormat + SwiftLint"
  ( cd "$IOS_REPO" && ./scripts/install-swiftformat.sh && ./scripts/install-swiftlint.sh )
}

setup_android() {
  [ -d "$ANDROID_REPO" ] || { log "clerk-android missing, skipping"; return; }
  log "clerk-android: warming Gradle dependencies (best-effort)"
  local java_home; java_home="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
  ( cd "$ANDROID_REPO" && JAVA_HOME="$java_home" ANDROID_HOME="$ANDROID_HOME" \
      ./gradlew --quiet :source:api:assembleDebug ) || log "clerk-android warm build skipped/failed (non-fatal)"
}

setup_javascript() {
  [ -d "$JS_REPO" ] || { log "javascript missing, skipping"; return; }
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  export PATH="$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH"
  log "javascript: pnpm install (frozen lockfile)"
  ( cd "$JS_REPO" && pnpm install --frozen-lockfile )
}

main() {
  install_apt_packages
  install_swift
  install_android_sdk
  install_node
  write_shell_env
  setup_ios
  setup_javascript
  setup_android
  log "Setup complete for clerk-ios, clerk-android, and javascript (@clerk/expo)."
}

main "$@"
