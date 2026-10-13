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

- macOS with Xcode 26+ installed
- Swift 6.2+
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
- `make test-integration` - Run only integration tests (requires `.keys.json` file; Clerk employees only)
- `make fetch-test-keys` - Fetch integration test keys from 1Password (optional, for Clerk employees only; auto-installs CLI if needed)

## Code Formatting

This project uses **SwiftFormat** for code formatting. The configuration is stored in `.swiftformat`.

- **Pinned version**: `0.60.0`

- **Indentation**: 2 spaces
- **Line length**: 1000 characters (very permissive)
- **Line breaks**: LF (Unix-style)
- **SwiftFormat parser version**: 5.10

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

### Pull request CI

For non-draft PRs authored by Clerk organization members, CI starts once after
CodeRabbit completes a review of the current commit and every review thread it
opened is resolved. Both signals are structured GitHub data (CodeRabbit's commit
status and review thread state), so CI doesn't depend on the wording of CodeRabbit's
comments. CodeRabbit resolves its own threads once they're addressed; resolving a
thread yourself also counts. Unresolved threads from people don't block the run.

CodeRabbit's automatic approval/request-changes workflow is explicitly disabled in
`.coderabbit.yaml`, with the organization's other settings inherited. CodeRabbit
never approves PRs.

After the first CI kickoff, new commits and retries require a Clerk member to comment
`/run ci`, or a Clerk member with write access to check **Run CI** in the instructions
comment. A manual kickoff before CodeRabbit finishes also counts as the first run.
External contributions and draft PRs use these manual controls.

Automatic and manual runs use the same checks, pinned to the requested commit. GitHub
has no workflow event for resolving a thread, so CI re-checks after CodeRabbit's own
review comment activity. If you resolve the last thread yourself after CodeRabbit
finishes, or CodeRabbit skips a review or is unavailable, use the manual controls.
The first kickoff is recorded in a separate bot comment so pushes, force-pushes, and
reopening the PR do not reset it.

The CI gate runs trusted scripts from the default branch, so workflow changes become
active after they land there. Run its regression tests locally with Node.js 22 or later:

```sh
node --test .github/scripts/pr-ci.test.cjs
```

`.github/workflows/verify-attach.yml` runs a second trusted script from the default branch,
`.github/scripts/verify-attach.mjs`. It puts the video and screenshots that a borrowed-device
verify session handed off into the description of that session's pull request. GitHub starts it
only when it and `.github/workflows/verify-remote.yml` are both on the default branch. It needs a
bot token, and without one the workflow publishes nothing. To set it up:

1. Create an environment named `verify-evidence` in the repository settings.
2. Limit the environment's deployment branches to the default branch.
3. Store the token in that environment as the secret `VERIFY_EVIDENCE_TOKEN`. It is a
   fine-grained personal access token of a machine account with write access, limited to this
   repository, with the permission "Pull requests: read and write".
4. Do not create a repository secret named `VERIFY_EVIDENCE_TOKEN`.

A repository secret can be read by a workflow that anyone with write access adds on any branch.
A secret of an environment that allows only the default branch cannot.

The `Run E2E runner tests` job of `shared-checks.yml` runs the script's tests. Run them locally
with Node.js 24 or later:

```sh
node --test .github/scripts/verify-attach.test.mjs
```

### Test suites

This project uses **Swift Testing** for package unit and integration tests, and the device tests in `e2e-tests/` for app-level E2E tests on an iOS Simulator. Tests are organized into three categories:

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
- Clerk employees can run `make fetch-test-keys` to populate it from 1Password via `scripts/fetch-1password-secrets.sh`; fetched entries may include both `pk` and optional `sk` values, such as reset-password fixtures, so do not strip `sk` values from `.keys.json`
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

E2E tests are the golden specs in `e2e-tests/specs/golden/`. They drive `Examples/E2EHost`, a dedicated SwiftUI test host app, on an iOS Simulator. They are an ordinary e2e project, and `e2e-tests/README.md` has the commands to run one by hand. The host app exists only for E2E coverage, keeping product-facing examples such as Quickstart free of test-only controls and launch configuration. The CLI creates a Clerk development instance for the worktree, and `down` deletes it, so the tests need no entry in `.keys.json`.

**Running E2E tests (Clerk employees only):**
```bash
npm ci --prefix e2e-tests
e2e-tests/bin/control-clerk-ios doctor
e2e-tests/bin/control-clerk-ios run --all
e2e-tests/bin/control-clerk-ios down
```

To run one feature:
```bash
e2e-tests/bin/control-clerk-ios run sign-up
```

**Requirements:**
- Network access
- Node.js 24, version 24.8 or later
- Xcode with an iOS Simulator runtime
- The team's Clerk Platform API key

`doctor` checks each requirement and prints the fix for one that is missing. `.claude/skills/verify-clerk-ios/SKILL.md` has the one-time machine setup, how to write a spec, and where a run keeps its video, screenshots, and logs.

The maintainer-only **Release SDK** workflow runs the same specs through `.github/workflows/verify-e2e.yml` and does not publish unless they pass.

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
