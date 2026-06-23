.PHONY: all clean setup format format-check lint lint-fix check check-e2e-hooks check-e2e-selectors check-e2e-phone-numbers install-tools install-hooks install-xcode-template-macros create-example-local-secrets-plists set-example-pk test test-ui test-e2e test-integration smoke-macos help create-env install-1password-cli fetch-test-keys sync-test-keys-to-github update-swiftformat update-swiftlint

SWIFTFORMAT := $(CURDIR)/.tools/bin/swiftformat
SWIFTLINT := $(CURDIR)/.tools/bin/swiftlint
IOS_SIMULATOR_DESTINATION ?=
CLERK_E2E_KEY_NAME ?= auth-email-code-password
E2E_ONLY_TESTING ?= E2EHostE2ETests
E2E_RESULT_BUNDLE_PATH ?= build/reports/E2EHost.xcresult
MACOS_DESTINATION ?= platform=macOS


# Default target
all: help

help:
	@echo "Available commands:"
	@echo "  make setup         - Install tools/hooks and configure Xcode file headers"
	@echo "  make fetch-test-keys - Fetch integration test keys from 1Password (optional, for Clerk employees; auto-installs CLI if needed)"
	@echo "  make sync-test-keys-to-github - Fetch test keys and sync them to the CLERK_TEST_KEYS_JSON GitHub Actions secret"
	@echo "  make format        - Format all Swift files using SwiftFormat"
	@echo "  make format-check  - Check formatting without modifying files (for CI)"
	@echo "  make lint          - Run SwiftLint to check code quality"
	@echo "  make lint-fix      - Run SwiftLint with auto-fix where possible"
	@echo "  make check         - Run format-check, lint, and E2E hook checks (for CI)"
	@echo "  make check-e2e-hooks - Verify E2E-only product hooks remain reviewed"
	@echo "  make check-e2e-selectors - Verify E2E selectors match their source contracts"
	@echo "  make check-e2e-phone-numbers - Verify E2E phone numbers use the approved test range"
	@echo "  make test          - Run ClerkKitTests on macOS"
	@echo "  make test-ui       - Run ClerkKitUI tests on iOS Simulator"
	@echo "  make test-e2e      - Run E2EHost tests on iOS Simulator"
	@echo "      CLERK_E2E_KEY_NAME=session-task-setup-mfa make test-e2e"
	@echo "      E2E_ONLY_TESTING='E2EHostE2ETests/E2EHostE2ETests/testName()' make test-e2e"
	@echo "  make test-integration - Run only integration tests"
	@echo "  make smoke-macos   - Build the Swift package and MacExampleApp on macOS"
	@echo "  make install-tools - Install pinned SwiftFormat and SwiftLint"
	@echo "  make update-swiftformat - Update pinned SwiftFormat to the latest release"
	@echo "  make update-swiftlint - Update pinned SwiftLint to the latest release"
	@echo "  make install-hooks - Set up pre-commit hook to auto-format staged Swift files"
	@echo "  make install-xcode-template-macros - Sync Xcode file header templates for workspace and package views"
	@echo "  make create-example-local-secrets-plists - Create LocalSecrets.plist files for examples from templates"
	@echo "  make set-example-pk pk_test_... - Set CLERK_PUBLISHABLE_KEY for all example LocalSecrets.plist files"

# Main setup command - installs tools and hooks
setup: install-tools install-hooks install-xcode-template-macros create-example-local-secrets-plists
	@echo "✅ Setup complete!"
	@echo "   Clerk employees: Run 'make fetch-test-keys' to populate integration test keys from 1Password"

# Create .keys.json file with blank integration test key if it doesn't exist
create-env:
	@./scripts/create-keys-json.sh

# Create LocalSecrets.plist files for all example apps from templates if missing
create-example-local-secrets-plists:
	@./scripts/create-example-local-secrets-plists.sh

# Set CLERK_PUBLISHABLE_KEY in all example LocalSecrets.plist files.
# Captures the argument from the raw make command line so keys ending in '$' are preserved.
# make set-example-pk pk_test_...
set-example-pk: create-example-local-secrets-plists
	@raw_make_command="$$(ps -o command= -p $$PPID)"; \
	publishable_key="$$(printf '%s\n' "$$raw_make_command" | awk '{ for (i = 1; i <= NF; i++) if ($$i == "set-example-pk") { print $$(i + 1); exit } }')"; \
	if [ -z "$$publishable_key" ]; then \
		echo "Usage: make set-example-pk pk_test_..."; \
		exit 1; \
	fi; \
	./scripts/set-example-publishable-key.sh "$$publishable_key"

ifneq (,$(filter set-example-pk,$(MAKECMDGOALS)))
%:
	@:
endif

# Install the repo-pinned SwiftFormat and SwiftLint
install-tools:
	@./scripts/install-swiftformat.sh
	@./scripts/install-swiftlint.sh

update-swiftformat:
	@./scripts/update-swiftformat-to-latest.sh

update-swiftlint:
	@./scripts/update-swiftlint-to-latest.sh

# Install pre-commit hook
install-hooks:
	@set -e; \
	hooks_dir="$$(git rev-parse --git-path hooks)"; \
	source_hook=".githooks/pre-commit"; \
	if [ -e "$$hooks_dir" ] && [ ! -d "$$hooks_dir" ]; then \
		echo "⚠️  Skipping pre-commit hook install because hooks path is not a directory: $$hooks_dir"; \
		exit 0; \
	fi; \
	target_hook="$$hooks_dir/pre-commit"; \
	mkdir -p "$$hooks_dir"; \
	source_abs="$$(cd "$$(dirname "$$source_hook")" && pwd)/$$(basename "$$source_hook")"; \
	target_abs="$$(cd "$$(dirname "$$target_hook")" && pwd)/$$(basename "$$target_hook")"; \
	if [ "$$source_abs" != "$$target_abs" ]; then \
		cp "$$source_hook" "$$target_hook"; \
	fi; \
	chmod +x "$$target_hook"; \
	echo "✅ Pre-commit hook installed"

# Install Xcode file header macros in both workspace and Swift package workspace
install-xcode-template-macros:
	@if [ ! -f Clerk.xcworkspace/xcshareddata/IDETemplateMacros.plist ]; then \
		echo "❌ Missing Clerk.xcworkspace/xcshareddata/IDETemplateMacros.plist"; \
		exit 1; \
	fi
	@mkdir -p .swiftpm/xcode/package.xcworkspace/xcshareddata
	@cp Clerk.xcworkspace/xcshareddata/IDETemplateMacros.plist .swiftpm/xcode/package.xcworkspace/xcshareddata/IDETemplateMacros.plist
	@echo "✅ Xcode file header macros configured"

# Install 1Password CLI via Homebrew (optional, for Clerk employees)
install-1password-cli:
	@echo "Checking for 1Password CLI..."
	@if ! command -v op > /dev/null; then \
		echo "Installing 1Password CLI via Homebrew..."; \
		brew install 1password-cli; \
	else \
		echo "✅ 1Password CLI installed"; \
	fi

# Fetch integration test keys from 1Password (optional, for Clerk employees only)
# Automatically installs 1Password CLI if not present
fetch-test-keys: install-1password-cli create-env
	@./scripts/fetch-1password-secrets.sh

# Sync the 1Password-backed .keys.json snapshot into GitHub Actions.
sync-test-keys-to-github: fetch-test-keys
	@./scripts/sync-test-keys-to-github.sh

# Format all Swift files
format:
	@echo "Formatting Swift files..."
	@./scripts/install-swiftformat.sh > /dev/null
	@"$(SWIFTFORMAT)" .

# Check formatting without modifying files
format-check:
	@echo "Checking Swift file formatting..."
	@./scripts/install-swiftformat.sh > /dev/null
	@"$(SWIFTFORMAT)" --lint .

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	@./scripts/install-swiftlint.sh > /dev/null
	@"$(SWIFTLINT)"

# Run SwiftLint with auto-fix
lint-fix:
	@echo "Running SwiftLint with auto-fix..."
	@./scripts/install-swiftlint.sh > /dev/null
	@"$(SWIFTLINT)" --fix

# Verify E2E-only product hooks are limited to reviewed OS automation workarounds
check-e2e-hooks:
	@./scripts/check-e2e-hooks.sh

# Verify E2E selectors are backed by product and E2EHost identifier contracts
check-e2e-selectors:
	@./scripts/check-e2e-selectors.sh

# Verify E2E phone numbers stay inside the approved Clerk test-number range
check-e2e-phone-numbers:
	@./scripts/check-e2e-phone-numbers.sh

# Run format-check, lint, and lightweight repo checks
check: format-check lint check-e2e-hooks check-e2e-selectors check-e2e-phone-numbers
	@echo "✅ All checks passed!"

clean:
	@echo "Cleaning Swift package build artifacts..."
	swift package clean

# Run ClerkKitTests on macOS
test:
	@echo "Running unit tests..."
	swift test --skip Integration --filter '^ClerkKitTests\.'
	CLERK_RUN_RECONFIGURE_TESTS=1 swift test --skip Integration --no-parallel --filter '^ClerkKitTests\.ClerkReconfigureTests'
	@echo "✅ Unit tests completed!"

# Build the Swift package and native macOS example app.
smoke-macos:
	@echo "Running macOS smoke build..."
	swift build
	xcodebuild build -workspace Clerk.xcworkspace -scheme MacExampleApp -destination "$(MACOS_DESTINATION)" CODE_SIGNING_ALLOWED=NO
	@echo "✅ macOS smoke build completed!"

# Run ClerkKitUI tests on iOS Simulator
test-ui:
	@echo "Running ClerkKitUI tests on iOS Simulator..."
	@mkdir -p .swiftpm/xcode/package.xcworkspace/xcshareddata
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<Workspace' \
		'   version = "1.0">' \
		'   <FileRef' \
		'      location = "self:">' \
		'   </FileRef>' \
		'</Workspace>' \
		> .swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata
	@if [ -f Clerk.xcworkspace/xcshareddata/IDETemplateMacros.plist ]; then \
		cp Clerk.xcworkspace/xcshareddata/IDETemplateMacros.plist .swiftpm/xcode/package.xcworkspace/xcshareddata/IDETemplateMacros.plist; \
	fi
	@destination="$(IOS_SIMULATOR_DESTINATION)"; \
	if [ -z "$$destination" ]; then \
		available_devices="$$(xcrun simctl list devices available)"; \
		simulator_id="$$(printf '%s\n' "$$available_devices" | sed -nE 's/^    (iPhone[^()]*) \(([0-9A-F-]{36})\) \(.*$$/\2/p' | head -n1)"; \
		if [ -n "$$simulator_id" ]; then \
			destination="platform=iOS Simulator,id=$$simulator_id"; \
		fi; \
	fi; \
	if [ -z "$$destination" ]; then \
		echo "❌ Unable to find an available iPhone simulator for ClerkKitUITests."; \
		echo "   Set IOS_SIMULATOR_DESTINATION explicitly and rerun make test-ui."; \
		exit 1; \
	fi; \
	echo "Using simulator destination: $$destination"; \
	xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme Clerk-Package -destination "$$destination" -only-testing:ClerkKitUITests
	@echo "✅ ClerkKitUI tests completed!"

# Run E2EHost tests on iOS Simulator
test-e2e:
	@echo "Running E2EHost tests on iOS Simulator..."
	@mkdir -p build/reports
	@key_name="$(CLERK_E2E_KEY_NAME)"; \
	if [ -z "$$key_name" ]; then \
		key_name="auth-email-code-password"; \
	fi; \
	publishable_key="$${CLERK_E2E_PUBLISHABLE_KEY:-}"; \
	if [ -z "$$publishable_key" ] && [ -f .keys.json ]; then \
		publishable_key="$$(/usr/bin/plutil -extract "$$key_name.pk" raw -o - .keys.json 2>/dev/null || true)"; \
	fi; \
	secret_key="$${CLERK_E2E_SECRET_KEY:-}"; \
	if [ -z "$$secret_key" ] && [ -f .keys.json ]; then \
		secret_key="$$(/usr/bin/plutil -extract "$$key_name.sk" raw -o - .keys.json 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$publishable_key" ]; then \
		echo "❌ Unable to find a publishable key for E2EHost tests."; \
		echo "   Set CLERK_E2E_PUBLISHABLE_KEY or configure '$$key_name.pk' in .keys.json."; \
		exit 1; \
	fi; \
	if [ "$${CLERK_E2E_SKIP_PREFLIGHT:-}" != "1" ]; then \
		CLERK_E2E_KEY_NAME="$$key_name" CLERK_E2E_PUBLISHABLE_KEY="$$publishable_key" CLERK_E2E_SECRET_KEY="$$secret_key" ./scripts/validate-e2e-test-instances.sh "$$key_name"; \
	else \
		echo "Skipping E2E test instance preflight because CLERK_E2E_SKIP_PREFLIGHT=1."; \
	fi; \
	echo "Using E2E test key: $$key_name"; \
	simulator_id=""; \
	destination="$(IOS_SIMULATOR_DESTINATION)"; \
	if [ -n "$$destination" ]; then \
		simulator_id="$$(printf '%s\n' "$$destination" | sed -nE 's/.*(^|,)id=([0-9A-Fa-f-]{36})(,.*|$$).*/\2/p')"; \
		if [ -z "$$simulator_id" ]; then \
			simulator_name="$$(printf '%s\n' "$$destination" | sed -nE 's/.*(^|,)name=([^,]+)(,.*|$$).*/\2/p')"; \
			if [ -n "$$simulator_name" ]; then \
				if ! command -v ruby >/dev/null; then \
					echo "❌ ruby is required to resolve IOS_SIMULATOR_DESTINATION name=$$simulator_name."; \
					exit 1; \
				fi; \
				simulator_id="$$(xcrun simctl list devices available -j | ruby -rjson -e 'target = ARGV.fetch(0).downcase; candidates = []; JSON.parse(STDIN.read).fetch("devices").each do |runtime, devices|; version = runtime[/SimRuntime[.]iOS-(.*)$$/, 1]; next unless version; version_parts = version.split("-").map(&:to_i); devices.each do |device|; next unless device["isAvailable"] && device["name"].downcase == target; candidates << [device["state"] == "Booted" ? 1 : 0, version_parts, device["udid"]]; end; end; selected = candidates.max_by { |candidate| [candidate[0], candidate[1]] }; puts selected[2] if selected' "$$simulator_name")"; \
				if [ -z "$$simulator_id" ]; then \
					echo "❌ Unable to find an available iOS simulator named '$$simulator_name'."; \
					exit 1; \
				fi; \
				destination="platform=iOS Simulator,id=$$simulator_id"; \
			fi; \
		fi; \
	fi; \
	if [ -z "$$destination" ]; then \
		available_devices="$$(xcrun simctl list devices available)"; \
		simulator_id="$$(printf '%s\n' "$$available_devices" | sed -nE 's/^    (iPhone[^()]*) \(([0-9A-Fa-f-]{36})\) \(.*$$/\2/p' | head -n1)"; \
		if [ -n "$$simulator_id" ]; then \
			destination="platform=iOS Simulator,id=$$simulator_id"; \
		fi; \
	fi; \
	if [ -z "$$destination" ]; then \
		echo "❌ Unable to find an available iPhone simulator for E2EHostE2ETests."; \
		echo "   Set IOS_SIMULATOR_DESTINATION explicitly and rerun make test-e2e."; \
		exit 1; \
	fi; \
	echo "Using simulator destination: $$destination"; \
	if [ -n "$$simulator_id" ]; then \
		echo "Preparing simulator keyboard preferences..."; \
		xcrun simctl boot "$$simulator_id" >/dev/null 2>&1 || true; \
		xcrun simctl bootstatus "$$simulator_id" -b >/dev/null; \
		xcrun simctl spawn "$$simulator_id" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool YES; \
	else \
		echo "Skipping simulator keyboard preference setup; destination does not include an explicit simulator id."; \
	fi; \
	result_bundle_path="$(E2E_RESULT_BUNDLE_PATH)"; \
	rm -rf "$$result_bundle_path"; \
	mkdir -p "$$(dirname "$$result_bundle_path")"; \
	only_testing="$(E2E_ONLY_TESTING)"; \
	only_testing_flags=""; \
	set -f; \
	for test_identifier in $$only_testing; do \
		only_testing_flags="$$only_testing_flags -only-testing:$$test_identifier"; \
	done; \
	set +f; \
	if [ -z "$$only_testing_flags" ]; then \
		echo "❌ E2E_ONLY_TESTING must contain at least one test identifier."; \
		exit 1; \
	fi; \
	printf '%s' "$$publishable_key" > build/reports/E2EHostPublishableKey.txt; \
	printf '%s' "$$key_name" > build/reports/E2EHostPublishableKeyName.txt; \
	chmod 600 build/reports/E2EHostPublishableKey.txt; \
	chmod 600 build/reports/E2EHostPublishableKeyName.txt; \
	trap 'rm -f build/reports/E2EHostPublishableKey.txt build/reports/E2EHostPublishableKeyName.txt' EXIT; \
	CLERK_E2E_KEY_NAME="$$key_name" CLERK_E2E_PUBLISHABLE_KEY="$$publishable_key" CLERK_PUBLISHABLE_KEY="$$publishable_key" CLERK_E2E_SECRET_KEY="$$secret_key" E2E_SIMULATOR_ID="$$simulator_id" E2E_RESULT_BUNDLE_PATH="$$result_bundle_path" ./scripts/run-e2e-xcodebuild.sh xcodebuild test -workspace Clerk.xcworkspace -scheme E2EHost -destination "$$destination" $$only_testing_flags -resultBundlePath "$$result_bundle_path"
	@echo "✅ E2EHost tests completed!"

# Run only integration tests
# Tests decide which key to use from .keys.json (each test can specify its own key)
# In CI, .keys.json is created from CLERK_TEST_KEYS_JSON GitHub Actions secret
# Locally, only Clerk employees can run integration tests (they have 1Password vault access)
# OSS contributors: Integration tests will run automatically in CI
test-integration:
	@./scripts/run-integration-tests.sh
