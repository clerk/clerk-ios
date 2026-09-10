# Live integration test migration

Reviewed both declarations and the complete helper/cleanup code in baseline
`02f98f89a19b6c079517c9aae07df7edd0e600e5`'s three `Tests/Integration` files.
These files are migrated in place, not retired.

| Baseline assertion/workflow | Generated replacement |
| --- | --- |
| `AuthAndClientIntegrationTests.signUpAndSignIn` creates an email/password sign-up, prepares and verifies an email code, signs out, then prepares and verifies email sign-in | `Clerk.connect`, `signUp.create`, `signUp.verifications.sendEmailCode/verifyEmailCode`, explicit `signUp.finalize`, `signOut`, `signIn.emailCode.sendCode/verifyCode`, explicit `signIn.finalize`. The test now checks completed attempt status, the created user/session identifiers, no selected user/session before each finalization, and the same user after sign-in. |
| Successful account cleanup and best-effort password recovery on failure | Successful cleanup now requires generated `user.delete()` to succeed. The failure path preserves the original error, tries generated password sign-in plus finalization if needed, and deletes the resulting test user when possible. An incomplete sign-up or failed recovery can still require instance-side cleanup. |
| `EnvironmentIntegrationTests.fetchAndDecodeEnvironment` refreshes the real environment | Generated `environment.reload()` after `Clerk.connect`, with loaded/signed-out state, a usable returned resource and a development/staging environment assertion. |
| Test configuration uses an in-memory Keychain and a mutable singleton | Each test owns and closes its connected core. Production ephemeral HTTP runs through `AppleCapabilities`; client and magic-link storage are separate in-memory actors. No Keychain, installation marker or system authentication capability is configured. |
| Local missing keys return without running; CI missing keys fail | Local missing keys disable both suites with a visible reason. CI enables them and fails with `missingPublishableKey`. A configured production key is rejected. `.keys.json` remains the default; `CLERK_TEST_KEYS_PATH` supports runners outside the checkout. |
| Local `native_api_disabled` could return without running the flow | A configured but unsupported instance now fails the test. It must support the required Native API/email-code flows; this is no longer silently counted as a local pass. |

The dedicated `ClerkIntegrationTests` target depends only on the generated
`ClerkKit` product. It is part of the default package test graph. The old
`ClerkKitTests` target remains declared with its other tests; its Integration
directory is excluded only because those same files now belong to the new
target. The integration script filters the new target name. Xcode's matching
scheme is installed by `make prepare-package-tests` and normal setup.

## Verification and remaining gate

On September 10, 2026, the new target compiled and both suites were discovered
on macOS and the iOS Simulator. Both were explicitly skipped because this
worktree had no `.keys.json`; this is **not a passing live API run**.
Running the compiled macOS target with `CI=1` failed both tests with
`missingPublishableKey("with-email-codes")`, as intended, before any network
connection or account creation.

The shell script passes `bash -n`. The first Xcode attempt exposed a missing
scheme; the checked-in scheme and setup copy now resolve it. The remaining
legacy target still prevents an unqualified `swift test` build. Its separate
assertion audits must be completed rather than bypassing that target.

A live development instance run remains required. It must verify the complete
new sign-up/sign-in/finalization/deletion path and environment reload with the
configured `with-email-codes` test instance. Packaged fixture checks elsewhere
do not substitute for that external integration gate.
