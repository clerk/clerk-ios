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
4. Create a `.env.local` file for integration test configuration (if it doesn't exist)

After running `make setup`, you're ready to start developing!

**For Clerk employees only:** After running `make setup`, you can optionally run `make fetch-secrets` to automatically populate integration test keys from 1Password. This will automatically install 1Password CLI if needed. This requires:
- Access to Clerk's Shared vault in 1Password
- 1Password desktop app integration enabled (see [1Password CLI setup guide](https://developer.1password.com/docs/cli/get-started/#step-2-turn-on-the-1password-desktop-app-integration))

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

- `make setup` - Install SwiftFormat, SwiftLint, set up pre-commit hook, and create .env.local file
- `make format` - Format all Swift files using SwiftFormat
- `make format-check` - Check formatting without modifying files (for CI)
- `make lint` - Run SwiftLint to check code quality
- `make lint-fix` - Run SwiftLint with auto-fix where possible
- `make check` - Run both format-check and lint (for CI)
- `make test` - Run unit tests
- `make test-integration` - Run only integration tests (requires .env.local file with publishable key; Clerk employees only)
- `make fetch-secrets` - Fetch integration test secrets from 1Password (optional, for Clerk employees only; auto-installs CLI if needed)

## Code Formatting

This project uses **SwiftFormat** for code formatting. The configuration is stored in `.swiftformat`.

- **Indentation**: 2 spaces
- **Line length**: 1000 characters (very permissive)
- **Line breaks**: LF (Unix-style)
- **Swift version**: 5.10

### Xcode Indentation Settings

To ensure consistent indentation in Xcode, configure your editor to use 2 spaces:

1. Open Xcode Preferences (⌘,)
2. Go to **Text Editing** → **Indentation**
3. Set **Tab Width** to `2`
4. Set **Indent Width** to `2`
5. Enable **Tab Key**: Inserts spaces, not tabs
6. Enable **Indent Using**: Spaces

**Note:** SwiftFormat will automatically format your code on commit, but configuring Xcode ensures consistency while editing.

## Code Linting

This project uses **SwiftLint** for code quality checks. The configuration is stored in `.swiftlint.yml`.

SwiftLint checks for:
- Code quality issues
- Style violations
- Potential bugs
- Best practices

## Testing

This project uses **Swift Testing** (not XCTest) for all tests. Tests are organized into two categories:

### Unit Tests

Unit tests are located in `Tests/` and use mocked API responses via the `Mocker` library. They are fast and don't require network access.

**Running unit tests:**
```bash
make test  # Run unit tests
```

**When to run unit tests:**
- Before committing any code changes
- During development for quick feedback
- When debugging specific functionality

### Integration Tests

Integration tests are located in `Tests/Integration/` and make real API calls to Clerk instances. They verify end-to-end functionality and require network access.

**Important:** Integration tests can only be run locally by **Clerk employees** who have access to the 1Password Shared vault. **OSS contributors** will have integration tests run automatically in CI - you don't need to run them locally.

**Running integration tests (Clerk employees only):**
```bash
make test-integration  # Run only integration tests
```

**Requirements:**
- Network access
- Valid Clerk test instance publishable key configured in `.env.local` file
- Test instance should be stable and not modified by other processes
- **Clerk employees only:** Access to Clerk's 1Password Shared vault

**Setup (Clerk employees only):**
1. Run `make setup` to create the `.env.local` file (if you haven't already)
2. Run `make fetch-secrets` to automatically populate `.env.local` from 1Password
   - This will automatically install 1Password CLI if not already installed
   - Requires access to Clerk's Shared vault and 1Password desktop app integration enabled
   - See [1Password CLI setup guide](https://developer.1password.com/docs/cli/get-started/#step-2-turn-on-the-1password-desktop-app-integration)
3. If `make fetch-secrets` doesn't work, you can manually add the key to `.env.local`:
   ```
   CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY=pk_test_...
   ```

**OSS contributors:**
- Integration tests will run automatically in CI for your pull requests
- You don't need to configure anything locally
- The `.env.local` file created by `make setup` will remain empty, which is expected

**How it works:**
- The `.env.local` file is automatically created by `make setup` with a blank key
- Clerk employees can run `make fetch-secrets` to populate it from 1Password
- `make test-integration` loads the key from `.env.local` and passes it as an environment variable
- The test code reads the key from the environment variable
- In CI, the key is automatically provided via GitHub Actions secrets

**Troubleshooting:**
- If integration tests fail with network errors, check your internet connection
- If tests fail with authentication errors, verify the test instance publishable key in `.env.local` is valid
- If `.env.local` file is missing, run `make setup` to create it
- If `make fetch-secrets` fails, ensure you have 1Password CLI installed and authenticated with access to the Shared vault
- Integration tests may be slower than unit tests due to real network calls
- Some tests may be flaky due to network conditions - consider retrying

## CI Workflow

Every pull request will automatically:

1. Run `make check` which includes:
   - Format checking (`make format-check`)
   - Linting (`make lint`)

2. Run unit tests (`make test`)

3. Run integration tests (`make test-integration`)
   - Requires `.env.local` file with `CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY` set (in CI, this is provided via GitHub Actions secrets)

4. Build for all supported platforms (iOS, macOS, macCatalyst, watchOS, tvOS, visionOS)

5. If code is not formatted, has lint violations, or tests fail, CI will fail

6. To fix issues locally:
   ```bash
   make format    # Fix formatting
   make lint-fix  # Fix lint issues
   make test      # Run unit tests
   ```

7. Commit and push again

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

