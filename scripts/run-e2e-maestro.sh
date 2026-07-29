#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

maestro_runner_bin="${MAESTRO_RUNNER_BIN:-}"
if [ -z "$maestro_runner_bin" ]; then
  maestro_runner_bin="$(command -v maestro-runner || true)"
fi
if [ -z "$maestro_runner_bin" ] && [ -x "$HOME/.maestro-runner/bin/maestro-runner" ]; then
  maestro_runner_bin="$HOME/.maestro-runner/bin/maestro-runner"
fi
if [ -z "$maestro_runner_bin" ] || [ ! -x "$maestro_runner_bin" ]; then
  echo "❌ maestro-runner is required: https://open.devicelab.dev/maestro-runner"
  exit 1
fi

flow_name="${E2E_MAESTRO_FLOW_NAME:-auth-email}"
case "$flow_name" in
  auth-email)
    default_key_name="auth-email-code-password"
    default_flow_path="Examples/E2EHost/Maestro/flows/auth-email-code-sign-up.yaml"
    ;;
  auth-phone)
    default_key_name="auth-phone-code"
    default_flow_path="Examples/E2EHost/Maestro/flows/auth-phone-code-sign-up.yaml"
    ;;
  user-profile)
    default_key_name="auth-email-code-password"
    default_flow_path="Examples/E2EHost/Maestro/flows/user-profile-security-delete-account.yaml"
    ;;
  session-task-setup-mfa)
    default_key_name="session-task-setup-mfa"
    default_flow_path="Examples/E2EHost/Maestro/flows/session-task-setup-mfa.yaml"
    ;;
  *)
    echo "❌ Unknown E2E_MAESTRO_FLOW_NAME '$flow_name'."
    echo "   Expected auth-email, auth-phone, user-profile, or session-task-setup-mfa."
    exit 1
    ;;
esac

key_name="${CLERK_E2E_KEY_NAME:-$default_key_name}"
publishable_key="${CLERK_E2E_PUBLISHABLE_KEY:-}"
secret_key="${CLERK_E2E_SECRET_KEY:-}"
flow_path="${E2E_MAESTRO_FLOW:-$default_flow_path}"
report_path="${E2E_MAESTRO_REPORT_PATH:-build/reports/maestro-$flow_name}"
build_duration=""
simulator_boot_duration=""
app_reset_duration=""
flow_duration=""
runner_setup_duration=""
command_execution_duration=""
log_pid=""
cleanup_identifier_type=""
cleanup_identifier_value=""
reports_root="$repo_root/build/reports"

case "$report_path" in
  /*) ;;
  *) report_path="$repo_root/$report_path" ;;
esac

if [ -L "$repo_root/build" ] || [ -L "$reports_root" ]; then
  echo "❌ '$repo_root/build/reports' must not resolve outside the repository."
  exit 1
fi
mkdir -p "$reports_root"
reports_root="$(cd "$reports_root" && pwd -P)"
if [ "$reports_root" != "$repo_root/build/reports" ]; then
  echo "❌ '$repo_root/build/reports' must not resolve outside the repository."
  exit 1
fi
report_path="$(ruby -e 'puts File.expand_path(ARGV.fetch(0))' "$report_path")"

if [ "$(dirname "$report_path")" != "$reports_root" ]; then
  echo "❌ E2E_MAESTRO_REPORT_PATH must be a direct child of '$reports_root'."
  exit 1
fi

rm -rf "$report_path"
mkdir -p "$report_path"

stop_log_stream() {
  if [ -n "$log_pid" ]; then
    kill "$log_pid" >/dev/null 2>&1 || true
    wait "$log_pid" 2>/dev/null || true
  fi
}

cleanup() {
  local exit_status="$?"

  stop_log_stream
  if [ "$exit_status" -ne 0 ] &&
    [ -n "$cleanup_identifier_type" ] &&
    [ -n "$cleanup_identifier_value" ] &&
    [ -n "$publishable_key" ] &&
    [ -n "$secret_key" ]; then
    CLERK_E2E_PUBLISHABLE_KEY="$publishable_key" \
      CLERK_E2E_SECRET_KEY="$secret_key" \
      ./scripts/cleanup-e2e-users.sh "$cleanup_identifier_type" "$cleanup_identifier_value" ||
      echo "⚠️  Failed to clean up the user created by the unsuccessful Maestro flow."
  fi

  trap - EXIT
  exit "$exit_status"
}
trap cleanup EXIT

if [ -z "$publishable_key" ] && [ -f .keys.json ]; then
  publishable_key="$(/usr/bin/plutil -extract "$key_name.pk" raw -o - .keys.json 2>/dev/null || true)"
fi

if [ -z "$secret_key" ] && [ -f .keys.json ]; then
  secret_key="$(/usr/bin/plutil -extract "$key_name.sk" raw -o - .keys.json 2>/dev/null || true)"
fi

if [ -z "$publishable_key" ]; then
  echo "❌ Unable to find a publishable key for the E2EHost Maestro flow."
  echo "   Set CLERK_E2E_PUBLISHABLE_KEY or configure '$key_name.pk' in .keys.json."
  exit 1
fi

if [ "${CLERK_E2E_SKIP_PREFLIGHT:-0}" != "1" ]; then
  CLERK_E2E_KEY_NAME="$key_name" \
    CLERK_E2E_PUBLISHABLE_KEY="$publishable_key" \
    CLERK_E2E_SECRET_KEY="$secret_key" \
    ./scripts/validate-e2e-test-instances.sh "$key_name"
else
  echo "Skipping E2E test instance preflight because CLERK_E2E_SKIP_PREFLIGHT=1."
fi

simulator_id="${E2E_SIMULATOR_ID:-}"
destination="${IOS_SIMULATOR_DESTINATION:-}"
simulator_name=""
simulator_os=""

if [ -n "$destination" ]; then
  simulator_name="$(printf '%s\n' "$destination" | sed -nE 's/.*(^|,)name=([^,]+)(,.*|$).*/\2/p')"
  simulator_os="$(printf '%s\n' "$destination" | sed -nE 's/.*(^|,)OS=([^,]+)(,.*|$).*/\2/p')"
fi

if [ -z "$simulator_id" ] && [ -n "$destination" ]; then
  simulator_id="$(printf '%s\n' "$destination" | sed -nE 's/.*(^|,)id=([0-9A-Fa-f-]{36})(,.*|$).*/\2/p')"
fi

if [ -z "$simulator_id" ] && [ -n "$simulator_name" ]; then
  simulator_id="$(
    xcrun simctl list devices available -j |
      ruby -rjson -e '
        target_name = ARGV.fetch(0).downcase
        target_os = ARGV.fetch(1, "")
        candidates = []
        JSON.parse(STDIN.read).fetch("devices").each do |runtime, devices|
          version = runtime[/SimRuntime[.]iOS-(.*)$/, 1]
          next unless version
          normalized_version = version.tr("-", ".")
          next if !target_os.empty? && target_os.downcase != "latest" && normalized_version != target_os
          version_parts = version.split("-").map(&:to_i)
          devices.each do |device|
            next unless device["isAvailable"] && device["name"].downcase == target_name
            candidates << [device["state"] == "Booted" ? 1 : 0, version_parts, device["udid"]]
          end
        end
        selected = candidates.max_by { |candidate| [candidate[0], candidate[1]] }
        puts selected[2] if selected
      ' "$simulator_name" "$simulator_os"
  )"

  if [ -z "$simulator_id" ]; then
    requested_simulator="$simulator_name"
    if [ -n "$simulator_os" ]; then
      requested_simulator="$requested_simulator running iOS $simulator_os"
    fi
    echo "❌ Unable to find the requested simulator: $requested_simulator."
    exit 1
  fi
fi

if [ -z "$simulator_id" ]; then
  simulator_id="$(
    xcrun simctl list devices available -j |
      ruby -rjson -e '
        target_os = ARGV.fetch(0, "")
        candidates = []
        JSON.parse(STDIN.read).fetch("devices").each do |runtime, devices|
          version = runtime[/SimRuntime[.]iOS-(.*)$/, 1]
          next unless version
          normalized_version = version.tr("-", ".")
          next if !target_os.empty? && target_os.downcase != "latest" && normalized_version != target_os
          version_parts = version.split("-").map(&:to_i)
          devices.each do |device|
            next unless device["isAvailable"] && device["name"].start_with?("iPhone")
            candidates << [device["state"] == "Booted" ? 1 : 0, version_parts, device["udid"]]
          end
        end
        selected = candidates.max_by { |candidate| [candidate[0], candidate[1]] }
        puts selected[2] if selected
      ' "$simulator_os"
  )"
fi

if [ -z "$simulator_id" ]; then
  echo "❌ Unable to find an available iPhone simulator for the E2EHost Maestro flow."
  echo "   Set E2E_SIMULATOR_ID or IOS_SIMULATOR_DESTINATION and rerun."
  exit 1
fi

destination="platform=iOS Simulator,id=$simulator_id"
simulator_build_arch="$(uname -m)"
case "$simulator_build_arch" in
  arm64 | x86_64) ;;
  *)
    echo "❌ Unsupported simulator build architecture: $simulator_build_arch"
    exit 1
    ;;
esac
derived_data_path="${E2E_MAESTRO_DERIVED_DATA_PATH:-build/e2e-maestro-derived-data}"
source_packages_path="${E2E_XCODE_SOURCE_PACKAGES_PATH:-build/xcode-source-packages}"

if [ ! -f "$flow_path" ]; then
  echo "❌ Maestro flow does not exist: $flow_path"
  exit 1
fi

mkdir -p "$derived_data_path" "$source_packages_path"

echo "Using simulator destination: $destination"
echo "Using Maestro flow: $flow_name"
echo "Using E2E test key: $key_name"
echo "Using Maestro flow: $flow_path"
echo "$("$maestro_runner_bin" --version | head -n 1)"

simulator_boot_started_at="$(date +%s)"
echo "Maestro E2E timing: simulator boot started at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true

build_started_at="$(date +%s)"
echo "Maestro E2E timing: E2EHost build started at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
xcodebuild build \
  -quiet \
  -workspace Clerk.xcworkspace \
  -scheme E2EHost \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$derived_data_path" \
  -clonedSourcePackagesDirPath "$source_packages_path" \
  ARCHS="$simulator_build_arch" \
  ONLY_ACTIVE_ARCH=YES \
  -showBuildTimingSummary
build_finished_at="$(date +%s)"
build_duration="$((build_finished_at - build_started_at))"
echo "Maestro E2E timing: E2EHost build finished in ${build_duration}s"

app_path="$derived_data_path/Build/Products/Debug-iphonesimulator/E2EHost.app"
if [ ! -d "$app_path" ]; then
  echo "❌ E2EHost build product was not found at $app_path."
  exit 1
fi

xcrun simctl bootstatus "$simulator_id" -b >/dev/null
simulator_boot_finished_at="$(date +%s)"
simulator_boot_duration="$((simulator_boot_finished_at - simulator_boot_started_at))"
echo "Maestro E2E timing: simulator boot finished in ${simulator_boot_duration}s (overlapped with build)"

xcrun simctl spawn "$simulator_id" defaults write com.apple.UIKit UIAnimationDragCoefficient -float 0.01 || true
xcrun simctl spawn "$simulator_id" defaults write -g ApplePersistenceIgnoreState -bool YES || true
xcrun simctl spawn "$simulator_id" defaults write com.apple.keyboard.AutoCapitalization -bool NO || true
xcrun simctl spawn "$simulator_id" defaults write com.apple.keyboard.AutoCorrection -bool NO || true
xcrun simctl spawn "$simulator_id" defaults write com.apple.keyboard.Prediction -bool NO || true

app_reset_started_at="$(date +%s)"
xcrun simctl terminate "$simulator_id" com.clerk.E2EHost >/dev/null 2>&1 || true
xcrun simctl uninstall "$simulator_id" com.clerk.E2EHost >/dev/null 2>&1 || true
xcrun simctl install "$simulator_id" "$app_path"
app_reset_finished_at="$(date +%s)"
app_reset_duration="$((app_reset_finished_at - app_reset_started_at))"
echo "Maestro E2E timing: E2EHost reset and install finished in ${app_reset_duration}s"

email_suffix="$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')"
test_email="${CLERK_TEST_EMAIL:-clerk_ios_maestro+clerk_test_$email_suffix@example.com}"
test_password="${CLERK_TEST_PASSWORD:-ClerkIOS2026E2EMaestro9!$email_suffix}"
keychain_service="${CLERK_E2E_KEYCHAIN_SERVICE:-com.clerk.E2EHost.Maestro.$email_suffix}"
phone_seed="$(printf '%s' "${GITHUB_RUN_ID:-$email_suffix}" | cksum | awk '{print $1}')"
printf -v generated_phone_number '5555550%03d' "$((100 + phone_seed % 100))"
test_phone_number="${CLERK_TEST_PHONE_NUMBER:-$generated_phone_number}"

if [ "$flow_name" = "auth-phone" ]; then
  cleanup_identifier_type="phone"
  cleanup_identifier_value="$test_phone_number"
  CLERK_E2E_PUBLISHABLE_KEY="$publishable_key" \
    CLERK_E2E_SECRET_KEY="$secret_key" \
    ./scripts/cleanup-e2e-users.sh phone "$test_phone_number"
else
  cleanup_identifier_type="email"
  cleanup_identifier_value="$test_email"
fi

xcrun simctl spawn "$simulator_id" log stream --style compact \
  --predicate 'processImagePath CONTAINS "E2EHost"' \
  > "$report_path/sim-console.log" 2>&1 &
log_pid=$!

flow_started_at="$(date +%s)"
echo "Maestro E2E timing: flow started at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
set +e
MAESTRO_DEVICE="$simulator_id" \
  MAESTRO_DRIVER="wda" \
  MAESTRO_PLATFORM="ios" \
  "$maestro_runner_bin" test \
    --output "$report_path/runner" \
    --flatten \
    --artifacts on-failure \
    --no-flutter-fallback \
    --env CLERK_E2E_PUBLISHABLE_KEY="$publishable_key" \
    --env CLERK_E2E_KEY_NAME="$key_name" \
    --env CLERK_E2E_KEYCHAIN_SERVICE="$keychain_service" \
    --env CLERK_TEST_EMAIL="$test_email" \
    --env CLERK_TEST_PASSWORD="$test_password" \
    --env CLERK_TEST_PHONE_NUMBER="$test_phone_number" \
    "$flow_path"
flow_status="$?"
set -e
flow_finished_at="$(date +%s)"
flow_duration="$((flow_finished_at - flow_started_at))"
echo "Maestro E2E timing: flow finished in ${flow_duration}s"

runner_report_path="$report_path/runner/report.json"
if [ -f "$runner_report_path" ]; then
  command_execution_duration="$(
    MAESTRO_RUNNER_REPORT_PATH="$runner_report_path" /usr/bin/ruby -rjson -e '
      report = JSON.parse(File.read(ENV.fetch("MAESTRO_RUNNER_REPORT_PATH")))
      milliseconds = report.fetch("flows", []).sum { |flow| Integer(flow.fetch("duration", 0)) }
      puts (milliseconds / 1000.0).round
    ' 2>/dev/null || true
  )"
  if [[ "$command_execution_duration" =~ ^[0-9]+$ ]]; then
    runner_setup_duration="$((flow_duration - command_execution_duration))"
    if [ "$runner_setup_duration" -lt 0 ]; then
      runner_setup_duration=0
    fi
    echo "Maestro E2E timing: runner and WDA setup took ${runner_setup_duration}s"
    echo "Maestro E2E timing: Maestro commands took ${command_execution_duration}s"
  fi
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### E2EHost Maestro ($flow_name)"
    echo
    echo "| Phase | Duration |"
    echo "| --- | ---: |"
    echo "| Simulator boot (overlapped) | ${simulator_boot_duration:-—}s |"
    echo "| E2EHost build | ${build_duration}s |"
    echo "| E2EHost reset and install | ${app_reset_duration:-—}s |"
    echo "| Runner and WDA setup | ${runner_setup_duration:-—}s |"
    echo "| Maestro commands | ${command_execution_duration:-—}s |"
    echo "| Maestro runner total | ${flow_duration}s |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$flow_status"
