# Contributing to Clerk iOS SDK

Thank you for your interest in contributing to the Clerk iOS SDK! This guide will help you get started with development.

## Development Setup

### First-Time Setup

Run the setup command to install all required tools and configure git hooks:

```bash
make setup
```

This command will:
1. Check if SwiftFormat is installed, and install it via Homebrew if needed
2. Check if SwiftLint is installed, and install it via Homebrew if needed
3. Set up the pre-commit hook to automatically format staged Swift files

After running `make setup`, you're ready to start developing!

### Prerequisites

- macOS with Xcode 16+ installed
- Swift 5.10+
- Homebrew (for installing SwiftFormat and SwiftLint)
- Git

## Development Workflow

### Daily Workflow

1. **Make your code changes** as usual

2. **When committing**, the pre-commit hook will automatically:
   - Format all staged Swift files using SwiftFormat
   - Re-stage the formatted files
   - If formatting changes files, you'll need to commit again

3. **Manual formatting** (if needed):
   ```bash
   make format        # Format all Swift files
   make format-check  # Check formatting without modifying files
   ```

4. **Linting** (if needed):
   ```bash
   make lint      # Check for lint issues
   make lint-fix  # Auto-fix lint issues where possible
   ```

5. **Run all checks** before pushing:
   ```bash
   make check  # Runs both format-check and lint
   ```

### Available Make Commands

- `make setup` - Install SwiftFormat, SwiftLint, and set up pre-commit hook
- `make format` - Format all Swift files using SwiftFormat
- `make format-check` - Check formatting without modifying files (for CI)
- `make lint` - Run SwiftLint to check code quality
- `make lint-fix` - Run SwiftLint with auto-fix where possible
- `make check` - Run both format-check and lint (for CI)
- `make install-tools` - Install SwiftFormat and SwiftLint via Homebrew
- `make install-hooks` - Set up pre-commit hook to auto-format staged Swift files

## Code Formatting

This project uses **SwiftFormat** for code formatting. The configuration is stored in `.swiftformat`.

- **Indentation**: 2 spaces
- **Line length**: 1000 characters (very permissive)
- **Line breaks**: LF (Unix-style)
- **Swift version**: 5.10

## Code Linting

This project uses **SwiftLint** for code quality checks. The configuration is stored in `.swiftlint.yml`.

SwiftLint checks for:
- Code quality issues
- Style violations
- Potential bugs
- Best practices

## CI Workflow

Every pull request will automatically:

1. Run `make check` which includes:
   - Format checking (`make format-check`)
   - Linting (`make lint`)

2. If code is not formatted or has lint violations, CI will fail

3. To fix issues locally:
   ```bash
   make format    # Fix formatting
   make lint-fix  # Fix lint issues
   ```

4. Commit and push again

## Bypassing Pre-commit Hook

If you need to bypass the pre-commit hook (not recommended), use:

```bash
git commit --no-verify
```

However, CI will still check formatting and linting, so you'll need to fix issues before merging.

## Getting Help

If you encounter any issues:

1. Make sure you've run `make setup`
2. Check that SwiftFormat and SwiftLint are installed: `which swiftformat` and `which swiftlint`
3. Try running `make check` to see what issues exist
4. Check the [SwiftFormat documentation](https://github.com/nicklockwood/SwiftFormat)
5. Check the [SwiftLint documentation](https://github.com/realm/SwiftLint)

## Questions?

Feel free to open an issue or reach out to the maintainers if you have questions about contributing!

