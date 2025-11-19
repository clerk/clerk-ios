.PHONY: setup format format-check lint lint-fix check install-tools install-hooks help

# Default target
help:
	@echo "Available commands:"
	@echo "  make setup         - Install SwiftFormat, SwiftLint, and set up pre-commit hook"
	@echo "  make format        - Format all Swift files using SwiftFormat"
	@echo "  make format-check  - Check formatting without modifying files (for CI)"
	@echo "  make lint          - Run SwiftLint to check code quality"
	@echo "  make lint-fix      - Run SwiftLint with auto-fix where possible"
	@echo "  make check         - Run both format-check and lint (for CI)"
	@echo "  make install-tools - Install SwiftFormat and SwiftLint via Homebrew"
	@echo "  make install-hooks - Set up pre-commit hook to auto-format staged Swift files"

# Main setup command - installs tools and hooks
setup: install-tools install-hooks
	@echo "✅ Setup complete! SwiftFormat, SwiftLint, and pre-commit hooks are ready."

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
	@swiftformat --lint .

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	@swiftlint

# Run SwiftLint with auto-fix
lint-fix:
	@echo "Running SwiftLint with auto-fix..."
	@swiftlint --fix

# Run both format-check and lint
check: format-check lint
	@echo "✅ All checks passed!"

