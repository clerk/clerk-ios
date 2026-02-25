.PHONY: setup format format-check lint lint-fix check install-tools install-hooks install-xcode-template-macros create-example-local-secrets-plists test test-integration help create-env install-1password-cli fetch-test-keys


# Default target
help:
	@echo "Available commands:"
	@echo "  make setup         - Install tools/hooks and configure Xcode file headers"
	@echo "  make fetch-test-keys - Fetch integration test keys from 1Password (optional, for Clerk employees; auto-installs CLI if needed)"
	@echo "  make format        - Format all Swift files using SwiftFormat"
	@echo "  make format-check  - Check formatting without modifying files (for CI)"
	@echo "  make lint          - Run SwiftLint to check code quality"
	@echo "  make lint-fix      - Run SwiftLint with auto-fix where possible"
	@echo "  make check         - Run both format-check and lint (for CI)"
	@echo "  make test          - Run unit tests"
	@echo "  make test-integration - Run only integration tests"
	@echo "  make install-tools - Install SwiftFormat and SwiftLint via Homebrew"
	@echo "  make install-hooks - Set up pre-commit hook to auto-format staged Swift files"
	@echo "  make install-xcode-template-macros - Sync Xcode file header templates for workspace and package views"
	@echo "  make create-example-local-secrets-plists - Create LocalSecrets.plist files for examples from templates"

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

# Install SwiftFormat and SwiftLint via Homebrew
install-tools:
	@if ! command -v swiftformat > /dev/null; then \
		echo "Installing SwiftFormat via Homebrew..."; \
		brew install swiftformat; \
	else \
		echo "✅ SwiftFormat installed"; \
	fi
	@if ! command -v swiftlint > /dev/null; then \
		echo "Installing SwiftLint via Homebrew..."; \
		brew install swiftlint; \
	else \
		echo "✅ SwiftLint installed"; \
	fi

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

# Format all Swift files
format:
	@echo "Formatting Swift files..."
	@swiftformat .

# Check formatting without modifying files
format-check:
	@echo "Checking Swift file formatting..."
	swiftformat --lint .

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	swiftlint

# Run SwiftLint with auto-fix
lint-fix:
	@echo "Running SwiftLint with auto-fix..."
	@swiftlint --fix

# Run both format-check and lint
check: format-check lint
	@echo "✅ All checks passed!"

# Run unit tests
test:
	@echo "Running unit tests..."
	swift test --skip Integration
	@echo "✅ Unit tests completed!"

# Run only integration tests
# Tests decide which key to use from .keys.json (each test can specify its own key)
# In CI, .keys.json is created from CLERK_TEST_KEYS_JSON GitHub Actions secret
# Locally, only Clerk employees can run integration tests (they have 1Password vault access)
# OSS contributors: Integration tests will run automatically in CI
test-integration:
	@./scripts/run-integration-tests.sh
