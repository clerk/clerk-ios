# Contributing to Clerk iOS SDK

Thank you for your interest in contributing to the Clerk iOS SDK! This guide will help you get started with development.

## Development Setup

### First-Time Setup

Run the setup command to install all required tools and configure git hooks:

```bash
make setup
```

This command will:
1. Install the repo-pinned SwiftFormat version
2. Install the repo-pinned SwiftLint version
3. Set up the pre-commit hook to automatically format staged Swift files
4. Configure Xcode file header templates for both `Clerk.xcworkspace` and Swift package workspace views
5. Create a `.keys.json` file for integration test configuration (if it doesn't exist)
6. Create `LocalSecrets.plist` files for example apps from `LocalSecrets.template.plist` files (if missing)

After running `make setup`, you're ready to start developing!

**For Clerk employees only:** After running `make setup`, you can optionally run `make fetch-test-keys` to automatically populate integration test keys from 1Password. This will automatically install 1Password CLI if needed. This requires:
- Access to Clerk's Shared vault in 1Password
- 1Password desktop app integration enabled (see [1Password CLI setup guide](https://developer.1password.com/docs/cli/get-started/#step-2-turn-on-the-1password-desktop-app-integration))

### Prerequisites

- macOS with Xcode 16+ installed
- Swift 5.10+
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
   make update-swiftformat  # Update the pinned SwiftFormat release
   ```

4. **Linting** (if needed):
   ```bash
   make lint      # Check for lint issues
   make lint-fix  # Auto-fix lint issues where possible
   make update-swiftlint  # Update the pinned SwiftLint release
   ```

5. **Run all checks** before pushing:
   ```bash
   make check  # Runs both format-check and lint
   ```

### Available Make Commands

- `make setup` - Install tools/hooks, configure Xcode file headers, and create example LocalSecrets plists
- `make install-tools` - Install pinned SwiftFormat and SwiftLint
- `make update-swiftformat` - Update pinned SwiftFormat to the latest release
- `make update-swiftlint` - Update pinned SwiftLint to the latest release
- `make install-hooks` - Install the pre-commit hook
- `make install-xcode-template-macros` - Sync Xcode file header templates for both workspace and package views
- `make create-example-local-secrets-plists` - Create `LocalSecrets.plist` files for examples if missing
- `make create-env` - Create the `.keys.json` file if missing
- `make format` - Format all Swift files using SwiftFormat
- `make format-check` - Check formatting without modifying files (for CI)
- `make lint` - Run SwiftLint to check code quality
- `make lint-fix` - Run SwiftLint with auto-fix where possible
- `make check` - Run both format-check and lint (for CI)
- `make test` - Run `ClerkKitTests` on macOS
- `make test-ui` - Run `ClerkKitUITests` on iOS Simulator
- `make test-e2e` - Run E2EHost tests on iOS Simulator
- `make test-integration` - Run only integration tests (requires `.keys.json` file; Clerk employees only)
- `make fetch-test-keys` - Fetch integration test keys from 1Password (optional, for Clerk employees only; auto-installs CLI if needed)

## Code Formatting

This project uses **SwiftFormat** for code formatting. The configuration is stored in `.swiftformat`.

- **Pinned version**: `0.60.0`

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

- **Pinned version**: `0.63.2`

SwiftLint checks for:
- Code quality issues
- Style violations
- Potential bugs
- Best practices

## Testing

This project uses **Swift Testing** for package unit and integration tests, and **XCTest/XCUITest** for app-level E2E UI automation. Tests are organized into three categories:

### Unit and UI Tests

`ClerkKitTests` live in `Tests/` and use mocked API responses via the `Mocker` library. `ClerkKitUITests` live in `Tests/UI` and run on an iOS Simulator.

**Running unit tests:**
```bash
make test  # Run ClerkKitTests on macOS
make test-ui  # Run ClerkKitUITests on iOS Simulator
```

**When to run unit tests:**
- Before committing any code changes
- During development for quick feedback
- When debugging specific functionality

### Integration Tests

Integration tests are located in `Tests/Integration/` and make real API calls to Clerk instances. They verify end-to-end functionality and require network access.

**Important:** Integration tests can only be run locally by **Clerk employees** who have access to the 1Password Shared vault. They are not part of the regular pull request CI workflow and are executed in the maintainer-only **Release SDK** workflow.

**Running integration tests (Clerk employees only):**
```bash
make test-integration  # Run only integration tests
```

Each test method must call `configureClerkForIntegrationTesting(keyName:)` at the start to specify which key to use.

**Requirements:**
- Network access
- Valid Clerk test instance publishable key configured in `.keys.json` file
- Test instance should be stable and not modified by other processes
- **Clerk employees only:** Access to Clerk's 1Password Shared vault

**Setup (Clerk employees only):**
1. Run `make setup` to create the `.keys.json` file (if you haven't already)
2. Run `make fetch-test-keys` to automatically populate `.keys.json` from 1Password
   - This will automatically install 1Password CLI if not already installed
   - Requires access to Clerk's Shared vault and 1Password desktop app integration enabled
   - See [1Password CLI setup guide](https://developer.1password.com/docs/cli/get-started/#step-2-turn-on-the-1password-desktop-app-integration)
3. If `make fetch-test-keys` doesn't work, you can manually add the key to `.keys.json`:
   ```json
   {
     "with-email-codes": {
       "pk": "pk_test_..."
     }
   }
   ```

**OSS contributors:**
- Integration tests are not run automatically for pull requests
- You don't need to configure anything locally
- The `.keys.json` file created by `make setup` will remain empty, which is expected

**How it works:**
- The `.keys.json` file is automatically created by `make setup` with a blank `with-email-codes.pk` entry
- Clerk employees can run `make fetch-test-keys` to populate it from 1Password (only includes `pk` values)
- Each test method must call `configureClerkForIntegrationTesting(keyName:)` with the desired key name at the start
- Tests read keys directly from `.keys.json` file
- In the maintainer-only **Release SDK** workflow, the `.keys.json` content is provided via `CLERK_TEST_KEYS_JSON` GitHub Actions secret (written to `.keys.json` before tests run)

**Troubleshooting:**
- If integration tests fail with network errors, check your internet connection
- If tests fail with authentication errors, verify the test instance publishable key in `.keys.json` is valid
- If `.keys.json` file is missing, run `make setup` to create it
- If `make fetch-test-keys` fails, ensure you have 1Password CLI installed and authenticated with access to the Shared vault
- Integration tests may be slower than unit tests due to real network calls
- Some tests may be flaky due to network conditions - consider retrying

### E2EHost Tests

E2E tests live in `Examples/E2EHost/` and run a dedicated SwiftUI test host app on an iOS Simulator with XCUITest. The host app exists only for release-gating E2E coverage, keeping product-facing examples such as Quickstart free of test-only controls and launch configuration. By default, these tests use the same Clerk test instance as the `with-email-codes` integration tests.

**Running E2E tests (Clerk employees only):**
```bash
make fetch-test-keys
make test-e2e
```

If CI is missing a named test key, add it to the 1Password item, then sync the GitHub Actions snapshot:
```bash
make sync-test-keys-to-github
```

You can also provide a key directly:
```bash
CLERK_E2E_PUBLISHABLE_KEY=pk_test_... make test-e2e
```

To run against a different named test instance from `.keys.json`:
```bash
CLERK_E2E_KEY_NAME=with-session-tasks-setup-mfa make test-e2e
```
If omitted, `CLERK_E2E_KEY_NAME` defaults to `with-email-codes`.
OAuth legal-consent examples include `with-legal-consent`.
Session-task examples include `with-session-tasks`, `with-session-tasks-reset-password`, and `with-session-tasks-setup-mfa`.

To choose a specific simulator:
```bash
IOS_SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 16' make test-e2e
```

**Requirements:**
- Network access
- Valid publishable key in `.keys.json` for `CLERK_E2E_KEY_NAME` or `CLERK_E2E_PUBLISHABLE_KEY`
- iOS Simulator available through `xcrun simctl`

The test runner writes its result bundle to `build/reports/E2EHost.xcresult`. In CI, this bundle is uploaded on failure. AI tools may help draft page objects, test flows, and accessibility ID changes, but generated tests must use the approved accessibility identifiers and be reviewed like production code. Maestro can be useful for exploratory mobile QA, but XCUITest is the release-gating E2E layer.

E2E cleanup uses the normal host-level delete-account control when possible. If a failure leaves the test inside an auth sheet or pending session-task screen, teardown relaunches `E2EHost` with the same keychain service and an E2E-only cleanup-on-launch flag so the app can delete the restored user without exposing a visible cleanup button.

## Releasing (Maintainers)

SDK releases can be published through the **Release SDK** GitHub Actions workflow:

1. Open **Actions** in GitHub and select **Release SDK**
2. Click **Run workflow**
3. Ensure the selected branch is `main`
4. Provide the target SemVer version (for example `1.2.3`)

The workflow automatically:
- Verifies the workflow actor has GitHub `maintain` or `admin` permission
- Runs formatting, linting, unit tests, integration tests, and multi-platform builds in the `checks` job
- Updates `Clerk.sdkVersion` in `Sources/ClerkKit/Utils/Version.swift` in the `publish` job
- Commits the version bump to `main`
- Creates and pushes tag `v<version>` in the `publish` job
- Publishes a GitHub Release with auto-generated release notes

## Questions?

Feel free to open an issue or reach out to the maintainers if you have questions about contributing!
