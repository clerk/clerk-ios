.PHONY: setup format format-check lint lint-fix check install-tools install-hooks test test-integration help create-env install-1password-cli fetch-test-keys


# Default target
help:
	@echo "Available commands:"
	@echo "  make setup         - Install SwiftFormat, SwiftLint, set up pre-commit hook, and create .keys.json file"
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

# Main setup command - installs tools and hooks
setup: install-tools install-hooks create-env
	@echo "✅ Setup complete! SwiftFormat, SwiftLint, pre-commit hooks, and .keys.json file are ready."
	@echo ""
	@echo "   Clerk employees: Run 'make fetch-test-keys' to populate integration test keys from 1Password"

# Create .keys.json file with blank integration test key if it doesn't exist
create-env:
	@./scripts/create-keys-json.sh

# Install SwiftFormat and SwiftLint via Homebrew
install-tools:
	@echo "Checking for SwiftFormat..."
	@if ! command -v swiftformat > /dev/null; then \
		echo "Installing SwiftFormat via Homebrew..."; \
		brew install swiftformat; \
	else \
		echo "✅ SwiftFormat is already installed"; \
	fi
	@echo "Checking for SwiftLint..."
	@if ! command -v swiftlint > /dev/null; then \
		echo "Installing SwiftLint via Homebrew..."; \
		brew install swiftlint; \
	else \
		echo "✅ SwiftLint is already installed"; \
	fi

# Install pre-commit hook
install-hooks:
	@echo "Setting up pre-commit hook..."
	@mkdir -p .git/hooks
	@cp .githooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Pre-commit hook installed"

# Install 1Password CLI via Homebrew (optional, for Clerk employees)
install-1password-cli:
	@echo "Checking for 1Password CLI..."
	@if ! command -v op > /dev/null; then \
		echo "Installing 1Password CLI via Homebrew..."; \
		brew install 1password-cli; \
	else \
		echo "✅ 1Password CLI is already installed"; \
	fi

# Fetch integration test keys from 1Password (optional, for Clerk employees only)
# Automatically installs 1Password CLI if not present
fetch-test-keys: install-1password-cli
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


