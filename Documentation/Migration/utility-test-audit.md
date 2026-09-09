# Utility assertion audit

Baseline: `02f98f89a19b6c079517c9aae07df7edd0e600e5`. This review read the utility
test bodies, not only their names. Exact declarations and source hashes remain in
[legacy-tests.json](legacy-tests.json). A retired helper API is not a claim that
every application behavior it previously supported has been validated.

| Old file / assertion group | Disposition in the generated-core API |
| --- | --- |
| `StringExtensionsTests`: `testIsEmptyTrimmed`, `testNonBreaking`, `testCapitalizedSentence`, `testIsEmailAddress` | All assertions are copied unchanged into `NativeCoreContractTests/StringPresentationTests.swift`. These four package helpers remain used by native UI. |
| `StringExtensionsTests`: base64 URL encoding/decoding and UTF-8 conversion | The general String extensions are removed. Passkey request bytes are checked by the public platform-capability tests; the PKCE RFC vector checks the native SHA-256 output's URL-safe encoding. General-purpose String conversion APIs are not part of the new profile. |
| `StringExtensionsTests.testToJSON` | The optional, permissive String-to-JSON helper is removed. `JSONValue` uses standard Codable and throws for malformed input; `SerializationContractTests` verifies this and nested JSON round trips. The old optional-null-on-invalid return policy is intentionally absent. |
| `OptionalStringExtensionsTests` | The nil/empty/whitespace trimming helper is removed and has no remaining source call site. No replacement SDK extension is introduced solely to retain its test. |
| `JSONUtilitiesTests`: enum cases, primitive extraction, null, Codable, equality | `SerializationContractTests.nestedMetadataKeepsNullsNumbersAndBooleansAcrossCodable` preserves nested JSON values and distinguishes numeric values from booleans. Typed accessors now throw on the wrong shape instead of returning nil. This is the bridge's explicit error policy. |
| `JSONUtilitiesTests`: literal conformances, array/object/dynamic-member/key-path subscripts | The former `JSON` convenience API is removed. `JSONValue` has explicit enum cases and typed extraction; no dynamic lookup or out-of-range optional subscript contract is claimed. |
| `JSONUtilitiesTests`: `merging*` and `mergePatch*` | The native merge and RFC 7396 patch helpers are removed. State delivery uses complete generated projections, and canonical User metadata behavior belongs to `clerk-js`. These tests are implementation-specific retirement candidates, not evidence that the core implements the old Swift merge API. |
| `JSONUtilitiesTests`: `testClerkDecoder`, `testClerkEncoder`, snake-case and millisecond-date cases | Native code no longer decodes FAPI resource payloads or globally transforms application Codable keys. `clerk-js` owns FAPI hydration and request encoding. `SerializationContractTests` verifies generated camel-case arguments, omitted/null/value distinctions, and both supported ISO-8601 date forms. |
| `URLEncodedFormEncoderTests.clerkFormMiddlewarePreservesNestedNullsInStringifiedMetadata` | Preserved at the current request-encoding owner: `packages/shared/src/internal/clerk-js/__tests__/querystring.test.ts`, `preserves nested nulls when metadata is stringified`. Generated Swift update arguments independently preserve the nested null. |
| Remaining `URLEncodedFormEncoderTests`: array/bool/data/date/key/key-path/nil/space policies, full struct encoding, invalid root, sorted keys, Data output | Retire with the removed configurable Swift form encoder. The new SDK does not expose those encoding policies; native HTTP executes the core's request body. The shared query-string suite verifies the canonical string, array, null, undefined, escaping, boolean, object and camel-to-snake behavior. Its exact output intentionally differs from some old customizable policies. |
| `URLEncodedFormEncoderTests`: all `protected*` cases | Retire with the removed lock-based `Protected` utility. The new native resource/runtime isolation has its own actor/transport contract; retaining a second concurrency utility for these tests would not verify that runtime. |
| `PKCETests.pkceChallengeMatchesRFC7636Vector` | Preserved by `AppleCryptoCapabilityTests.nativeSHA256MatchesThePKCERFC7636Vector`, invoking the public native capability used by the core. |
| `PKCETests.generatedPKCEPairUsesS256CompatibleValues` | Preserved at the owner in `packages/mobile-runtime/test/magic-link.test.mjs`: sign-in and sign-up link requests use a 43-character URL-safe verifier and the S256 digest of that stored verifier. The TypeScript flow, persistence and request are exercised together. |
| `PrivacyManifestTests.bundledManifestDeclaresUserDefaults` | ClerkKitUI still declares `CA92.1`, now checked in its own UI target. The core no longer uses UserDefaults; its separate contract test verifies the bundled manifest's empty required-reason API list. This tests packaging and declared contents, not store approval or a legal compliance determination. |
| `VersionTests.clerkVersion` | `scripts/check-version-consistency.sh` validates the new prerelease SemVer and the actual `NativeCore/Version.swift` source. The old assertion that every dot-separated component is numeric incorrectly rejects prereleases and is not retained. |
| `VersionTests.testDeviceID` | `DeviceHelper.deviceID` is removed. The generated SDK does not promise an installation UUID through that old helper. Credential scoping and migration are separately validated and are not inferred from UUID formatting. |
| `HTTPURLResponseExtensionsTests` | All seven tests exercise removed native status-classification/description extensions, including synthetic 0/99/600/999 cases. Native HTTP now returns the raw status to the core; it does not classify a Clerk domain error or expose those descriptions. Retire those helper assertions; HTTP-host execution/security assertions belong to the platform transport audit. |
| `LocaleUtilsTests` | The two shape checks exercise the removed native `LocaleUtils.userLocale()` helper. They do not prove localized UI or request negotiation. No locale equivalence claim is made for the generated SDK from these checks. |
| `ExternalAuthUtilsTests` | The six nonce-parser cases are now owned by TypeScript callback orchestration. Existing SSO tests check nonce forwarding and reject an unrelated callback route. Empty/missing nonce and fragment cases require callback-contract review before treating these six old cases as fully replaced. |
| `RetryingOperationTests` | The four attempt/delay-policy assertions target a removed independent Swift retry algorithm. Retry decisions now belong to the core. Retire the helper's exact counter and clamp policy; platform cancellation and token-retry behavior remain in their separate audits. |
| `SessionUtilsTests` | The five current-session selection and eleven identity/status/date-change cases belong to the core state/observation audit. Existing active/pending adoption and projection tests are relevant, but this utility review does not claim all those old transitions have been checked. |
| `SessionStatusLoggerTests` | All twelve tests decide when a removed native logger should emit a pending-session message, including nil/empty task normalization. That logger is intentionally absent. Native UI must still enforce pending tasks, which is checked through the core/UI completion contract rather than logging decisions. |
| `ProxyConfigurationTests` | The sixteen URL validation and prefix cases describe an explicitly unavailable prerelease feature. They remain evidence of that limitation, not passing replacement coverage. |
| `JSONWebAuthnTests`, `WebAuthenticationTests` | See the separate [passkey](passkey-test-audit.md) and [browser](browser-test-audit.md) assertion maps. |

Validation on 2026-09-09: the complete macOS native contract target passes 24 test
declarations across eight suites, including the copied presentation assertions;
the selected iOS UI privacy test passes; the shared query-string suite passes 17
tests; and the mobile email-link suite passes 11 tests. These are separate test
runs and are not a legacy coverage percentage. `StringExtensionsTests`,
`PKCETests`, `PrivacyManifestTests`, and `VersionTests` are retired after the
passing replacement checks. Other utility files remain retained while their
dispositions and the broader target migration are reviewed.
