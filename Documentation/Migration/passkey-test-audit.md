# Passkey request assertions

This audit covers all three declarations in `Tests/Utils/JSONWebAuthnTests.swift`
and the declaration in `Tests/Domains/Auth/Passkey/PasskeyHelperTests.swift` at
baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`.

The new tests invoke the public `AppleAuthentication.credential` capability and
inspect the real AuthenticationServices request delivered to an internal
controller factory. A stub controller completes or cancels the request without
opening system UI. The production factory remains `ASAuthorizationController`.

| Old test | Assertions and current disposition |
| --- | --- |
| `assertionRelyingPartyIdentifierReadsNonce` | The `example.com` relying party is preserved in the assertion request, checked by `assertionPreservesRelyingPartyChallengeAndCredentialRestrictions`. The core now supplies normalized bridge binary values. |
| `assertionAllowedCredentialIDsDecodeBase64URLIDs` | `AQIDBA` and `aGVsbG8` still become the bytes `[1, 2, 3, 4]` and `hello` in the same request test. The allowed-credential restriction is passed to the OS. |
| `assertionAllowedCredentialIDsIgnoreInvalidEntries` | Intentionally changed: a missing, empty, or malformed credential ID rejects the entire request before presentation. Silently dropping restrictions is not retained. `malformedCredentialRestrictionsFailBeforePresentation` checks all three cases alongside a valid ID. This exposed and fixed acceptance of empty binary values. |
| `credentialAssertionRequestSetsAllowedCredentials` | The one-ID helper assertion is subsumed by inspecting both actual OS credential descriptors in the public-capability test. No replacement native passkey domain helper is introduced. |

Additional tests cover registration challenge/user fields/excluded credentials,
user-verification preference, cancellation and a stale controller callback, Apple
identity scope requests, a shared occupied presenter, and structured failures.
All five new test declarations pass on macOS and the iOS Simulator together with
the packaged-core and browser suites. Registration exclusion is platform-gated;
these runs do not prove visionOS exclusions or live passkey enrollment.

The Android request suite also rejects empty/malformed bridge credential IDs and
checks the Credential Manager JSON for allowed/excluded credentials and user data.
Neither platform suite proves a system prompt, provider callback, or a signed-in
application upgrade. The old test files remain retained during the broader audit.
