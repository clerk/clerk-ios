# Rendered iOS authentication journey

`Examples/AuthJourney` renders the production SwiftUI `AuthView` inside an application
connected to the actual packaged JavaScriptCore owner. XCUITest operates the native
controls. HTTP and in-memory credential persistence are deterministic fixtures;
neither the app nor the UI test calls `finalize()` or assigns a selected session.

The test verifies three stages:

1. Enter `test@example.com`, tap Continue, and reach email-code verification with
   no selected session, no user and no completion callback.
2. Enter `000000`. The native screen and error sheet display the structured error.
   No session, callback or finalization touch is published. Close the error sheet.
3. Replace the code with `424242`. Production prebuilt UI finalizes the attempt.
   The application's `clerk.isAuthFlowComplete` branch reveals authenticated
   content. The active session, expected user, exactly one completion callback,
   exactly one finalization touch and the ordered pair of submitted codes are asserted.

The existing `AuthFlowCoreTests` separately exercise pending tasks, registration
ownership, external activation, repeated completion and cancellation. This rendered
journey adds evidence for native typing, navigation, error presentation and the
prebuilt flow's call into the generated API.

## Run and retained evidence

Run `make test-auth-journey` from the repository, or invoke
`scripts/run-auth-view-journey.sh` through Bash from any working directory. The
runner requires an iOS Simulator and a fresh result bundle. It verifies the exact
named XCTest case and all three named PNG attachments. The existing shared iOS CI
job now invokes it and uploads its evidence. **The added CI step has not run remotely.**

On September 10, 2026, the complete runner passed on the arm64 iPhone Air Simulator,
iOS 26.5. The final formatted source passed one UI test with no failure, error,
expected failure or skip. Its 16.65-second duration includes UI automation and is
not a startup or performance measurement. The [proof record](evidence/auth-view-journey/proof.json)
identifies the source hashes, native base, packaged bundle, dependency pins, device
and results. The [test tree](evidence/auth-view-journey/tests.json) and
[summary](evidence/auth-view-journey/summary.json) preserve the named result.

All retained screenshots were visually inspected:

- [Identifier entry](evidence/auth-view-journey/01-identifier.png)
- [Invalid-code error and native error sheet](evidence/auth-view-journey/02-invalid-code.png)
- [Authenticated test-host content and completion counts](evidence/auth-view-journey/03-completed.png)

The evidence checker rejected deliberately missing, duplicate, wrong, failed and
skipped test cases, a non-Simulator device, missing attachment records and invalid
bytes for each of the three screenshots. Shell syntax checking passed. The updated
workflow has the same two actionlint findings as its unchanged baseline: the existing
custom Blacksmith label and the installed parser's rejection of `concurrency.queue`.
With those two existing findings filtered, the changed workflow passes actionlint;
ShellCheck was unavailable.

## Setup corrections and limits

Initial runs exposed test-app setup issues: the app needed its dependency lockfile,
and Debug needed the active Simulator architecture to match Swift package builds.
The empty identifier control is exposed as a container before focus, so the UI test
uses its existing accessibility identifier rather than requiring a TextField role.
The invalid-code screen also presents an error sheet; the test must tap Close before
editing the code underneath it. Correcting the test's interaction completed the
journey without changing production SDK behavior.

Xcode reported App Intents metadata skipping, unavailable debugger version metadata,
and a duplicate accessibility loader class from the installed Simulator runtime.
These warnings did not prevent the final test from passing. SwiftFormat formatted
the test app but could not write its user-cache file in the restricted environment.

This proves the recorded rendered fixture flow on one Simulator. Live authentication,
real browser/passkey/biometric prompts, actual old-major signed-in app upgrades,
minimum-OS execution and physical-device performance remain separate release gates.
