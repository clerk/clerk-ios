.PHONY: setup format format-check lint lint-fix check install-tools install-hooks test test-unit test-integration help create-env

# Load .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Default target
help:
	@echo "Available commands:"
	@echo "  make setup         - Install SwiftFormat, SwiftLint, set up pre-commit hook, and create .env file"
	@echo "  make format        - Format all Swift files using SwiftFormat"
	@echo "  make format-check  - Check formatting without modifying files (for CI)"
	@echo "  make lint          - Run SwiftLint to check code quality"
	@echo "  make lint-fix      - Run SwiftLint with auto-fix where possible"
	@echo "  make check         - Run both format-check and lint (for CI)"
	@echo "  make test          - Run all tests (unit + integration)"
	@echo "  make test-unit     - Run only unit tests (exclude integration tests)"
	@echo "  make test-integration - Run only integration tests"
	@echo "  make install-tools - Install SwiftFormat and SwiftLint via Homebrew"
	@echo "  make install-hooks - Set up pre-commit hook to auto-format staged Swift files"

# Main setup command - installs tools and hooks
setup: install-tools install-hooks create-env
	@echo "✅ Setup complete! SwiftFormat, SwiftLint, pre-commit hooks, and .env file are ready."

# Create .env file with blank integration test key if it doesn't exist
create-env:
	@if [ ! -f .env ]; then \
		echo "Creating .env file..."; \
		echo "# Integration Test Configuration" > .env; \
		echo "# Add your Clerk test instance publishable key below" >> .env; \
		echo "# Get the key from your Clerk Dashboard or ask a team member for the integration test instance key" >> .env; \
		echo "CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY=" >> .env; \
		echo "✅ Created .env file. Please add your integration test publishable key."; \
	else \
		echo "✅ .env file already exists."; \
	fi

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

# Run all tests (unit + integration)
test: test-unit test-integration
	@echo "✅ All tests completed!"

# Run only unit tests (exclude integration tests)
test-unit:
	@echo "Running unit tests..."
	swift test --skip Integration

# Run only integration tests
# Automatically loads CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY from environment variable or .env file
# In CI, the environment variable is provided via GitHub Actions secrets
# Locally, it can be set as an environment variable or in the .env file
test-integration:
	@echo "Running integration tests..."
	@echo "⚠️  Note: Integration tests require network access and a valid Clerk test instance"
	@if [ -n "$$CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY" ]; then \
		echo "Using CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY from environment variable"; \
		swift test --filter Integration; \
	elif [ -f .env ]; then \
		echo "Loading CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY from .env file"; \
		export $$(cat .env | grep -v '^#' | xargs); \
		swift test --filter Integration; \
	else \
		echo "❌ Error: CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY not found."; \
		echo "   Set it as an environment variable or add it to .env file."; \
		echo "   Run 'make setup' to create .env file."; \
		exit 1; \
	fi


