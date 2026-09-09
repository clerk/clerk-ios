# Session verification test migration audit

The generated Session API executes canonical TypeScript verification methods. The test fixtures assert actual HTTP and returned observable state instead of forwarding to a native mock service. This inventory covers all 18 declarations in retained `Tests/Domains/Auth/Session/SessionTests.swift`; the file remains retained because revoke and task assertions are not closed here.

## Evidence and boundaries

- Shared embedded `packages/mobile-runtime/test/session-verification.test.mjs`: 18 tests including generated request/response cases, passkey host success/cancellation, invalid-code recovery, and rejection of the unavailable inherited reload without HTTP.
- Swift `NativeCoreContractTests/SessionVerificationTests.swift` and Android `NativeCoreTests/Android/SessionVerificationTest.kt`: one test on each host exercises 14 successful generated calls, a structured 422 error, and a successful retry. Assertions cover nested factor metadata and state at completion.
- Native fixture requests use packaged JavaScriptCore/QuickJS, not live FAPI or OS credential prompts. The two passkey host lifecycle cases are embedded tests; native cases cover passkey preparation only.

SessionVerification remains an observable resource, but its inherited reload is explicitly unavailable: the source implementation has no pathRoot and generated GET `/v1sv_fixture` during the pre-fix proof. The checked binding policy excludes that method while retaining resource identity. The generated API diff removes only that method. Advance verification using the owning Session methods.

## Legacy assertion map

| Legacy test | Replacement or remaining work |
| --- | --- |
| `revokeUsesSessionServiceRevoke` | Pending the separate session revoke/selection/cache audit; service forwarding alone is not sufficient evidence. |
| `taskKeyParsesSetupMfa` | Pending an exact generated task projection assertion inventory. |
| `taskKeyParsesResetPassword` | Pending an exact generated task projection assertion inventory. |
| `taskKeyParsesUnknownTask` | Pending an exact generated unknown-task projection assertion inventory. |
| `sessionVerificationDecodesSupportedFactorMetadata` | Embedded and both native hosts read enterprise connection id/name and phone id/safe identifier/primary/default from the returned generated resource. |
| `startVerificationForwardsLevelToService` | Actual generated HTTP request verifies session id and each of the three levels; returned status comes from the response. |
| `sendEmailCodeCallsPrepareFirstFactor` | Generated prepareFirstFactorVerification email case checks strategy, email id, and returned state. |
| `sendPhoneCodeCallsPrepareFirstFactor` | Generated prepareFirstFactorVerification phone case checks strategy, phone id, default flag, and returned state. |
| `verifyWithEmailCodeCallsAttemptFirstFactor` | Generated first-factor email attempt checks strategy/code, usable completed result, structured invalid-code error, and retry. |
| `verifyWithPhoneCodeCallsAttemptFirstFactor` | Generated first-factor phone attempt checks strategy/code and returned state. |
| `verifyWithPasswordCallsAttemptFirstFactor` | Generated first-factor password attempt checks strategy/password and returned state. |
| `startEnterpriseSSOCallsPrepareFirstFactor` | Generated enterprise preparation checks email id, connection id, redirect URL and returned state. |
| `startEnterpriseSSOUsesDefaultRedirectUrl` | Intentional source contract difference: redirectUrl is required explicitly. No handwritten native default is added. |
| `sendMfaPhoneCodeCallsPrepareSecondFactor` | Generated phone second-factor preparation checks strategy/phone id and needs_second_factor. |
| `verifyWithMfaPhoneCodeCallsAttemptSecondFactor` | Generated phone second-factor attempt checks strategy/code and completion. |
| `passkeyCredentialCallsAttemptSecondFactor` | Not in the canonical second-factor union. Embedded Session.verifyWithPasskey proves first-factor prepare/platform-host/attempt and cancellation; live OS acceptance remains separate. |
| `verifyWithTOTPCallsAttemptSecondFactor` | Generated TOTP second-factor attempt checks strategy/code and completion. |
| `verifyWithBackupCodeCallsAttemptSecondFactor` | Generated backup-code second-factor attempt checks strategy/code and completion. |

## Session service assertions

The retained `SessionServiceTests.swift` verification subset is covered as follows: `startVerification`, `prepareFirstFactorVerificationPasskey`, `prepareFirstFactorVerificationEnterpriseSSO`, and `attemptSecondFactorVerificationTOTP` map to the actual generated requests above. `attemptFirstFactorVerificationPasskey` now uses the typed/platform credential path; the embedded source flow verifies that its serialized signature reaches the request. The old arbitrary JSON-string parameter is not retained. Enterprise requests omit unrelated default fields because the form body is compared exactly.

The other service tests cover sign-out/cache failure, organization activation, token minting, and revoke. This audit does not mark those assertions migrated or authorize deletion. Explicit enterprise redirectUrl and the absence of passkey in the canonical second-factor union are source contract changes, not new native state machines.

## Packaged validation

Source revision `ccb9d8f3d5a2089c4e573b32ec77a5bfe7816d20`, contract `fc919ded53c772af190eb2a07f5fdec94a7f1f47fbc2b04b4a3ab76c4d39bf16`, bundle SHA-256 `a22861770e84f6c6b00658616e561488866d09895fda8f30e041978e1777b53b`. The complete embedded suite passes 295 tests and the generator passes 14. Runtime type checking and attached-core generation checks pass. Packaged Apple contract suites pass 74 tests on macOS and 71 on iOS Simulator. Android instrumentation passes 48 enabled tests; benchmark and live-service tests opt out through JUnit assumptions. The Android XML exporter records those two assumptions as failure elements although Gradle reports success; neither is runtime failure evidence or an executed acceptance gate.
