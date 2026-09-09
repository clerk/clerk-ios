# Browser presentation assertions

This audit covers every test declaration in the old
`Tests/Utils/WebAuthenticationTests.swift` at baseline
`02f98f89a19b6c079517c9aae07df7edd0e600e5`. Its stub implements the OS session
boundary; it does not prove a live provider login or a system prompt.

The new adapter is `NativeCore/AppleAuthentication.swift`. Its injected session
factory is internal; production still creates `ASWebAuthenticationSession` with
the configured scheme or HTTPS host/path. Tests invoke the public `openBrowser`
capability and assert caller results, cancellation, and subsequent presentation.

| Old test | Assertions and current disposition |
| --- | --- |
| `startFailureResumesCallerAndAllowsNextSession` | A false OS `start()` completes with an error and frees presentation for another request. Preserved by `failedStartResumesTheCallerAndAllowsTheNextSession`; the structured code is now `browser_presentation_failed`. |
| `taskCancellationCancelsSystemSessionAndAllowsNextSession` | Cancelling the awaiting task cancels the OS session, throws `CancellationError`, and permits another request. Preserved by `taskCancellationReleasesThePresenterAndIgnoresItsLateCallback`. |
| `cancelCurrentSessionCancelsSystemSessionAndResumesCaller` | The old process-wide static cancellation API is intentionally absent. Cancellation now belongs to the invoking task/core. Its OS cancellation and caller completion outcomes are covered by the task-cancellation test above. No process-global cancellation method is claimed to remain available. |
| `staleCompletionAfterCancellationDoesNotCompleteNextSession` | A cancelled session's late callback cannot supply the next call's result. Preserved by `taskCancellationReleasesThePresenterAndIgnoresItsLateCallback`. |
| `secondStartFailsWithoutOverwritingActiveSession` | Competing calls on one presenter fail while the active call still returns its own callback. Preserved by `competingCallDoesNotReplaceTheActiveSession`; the code is now `presentation_in_progress`. The new guard is per retained presenter, not a global SDK singleton. |

The new suite additionally checks duplicate completion after success and structured
OS-user cancellation. The audit found a regression in the first adapter: callback
completion lacked an operation identity. Removing the added identity guard makes
the stale-callback and duplicate-completion tests fail; restoring it makes all five
browser tests pass. Cancellation handlers also carry their operation identity so
an asynchronously delivered cancellation cannot affect a later request.

The old source file remains retained pending the broader test-target migration.
These results do not retire unreviewed passkey, keychain, or biometric assertions.
