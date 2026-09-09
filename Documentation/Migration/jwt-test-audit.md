# JWT decoding assertion audit

All sixteen tests in the old `Tests/Utils/JWTDecoderTests.swift` were read. Its standalone Swift JWT/Claim parser is removed; the generated session API returns the canonical raw string from `Session.getToken`. No independently maintained Swift expiration or claim-coercion layer is introduced.

| Old assertions | Current contract and proof |
| --- | --- |
| `decodeValidJWT`, `jWTClaimExtraction` | `clerk-js` decodes registered subject/issuer/audience/expiration/issued-at/not-before/JTI claims. The expanded TypeScript decoder test checks their exact values. |
| Invalid part count (one/two/four), invalid base64 URL, invalid JSON | The TypeScript decoder rejects each malformed form. Native-specific `JWTDecodeError` cases are intentionally gone. The embedded generated `Session.getToken` path separately rejects malformed token responses while preserving its session and allowing subsequent resource operations. |
| `jWTExpired` (past/future/no expiration) | The removed standalone `.expired` convenience is not generated. Token validity, freshness, cache and retry policy belong to `Session` and the shared token cache, whose separate 166-test audit covers native background/foreground and stale-token behavior. This parser audit does not assert an equivalent missing-expiration convenience policy. |
| `claimString`, `claimBoolean`, `claimDouble`, `claimInteger` | Claims retain exact JSON types in TypeScript, including true/false and numeric-looking strings. The old Claim wrapper's string-to-number coercions are absent. Native callers receive the raw token rather than this wrapper. |
| `claimDate` | JWT numeric timestamps remain seconds in the core claims. No standalone Swift Date conversion helper is exposed. The source test checks exact numeric timestamp values. |
| `claimArray`, `claimSubscript` | Arrays and scalar strings remain distinct; there is no old scalar-to-array or optional typed-subscript facade. Source assertions retain both array and scalar values, plus nested nulls. |
| `jWTStringValue`, `jWTHeader`, `jWTSignature` | The source test checks the exact raw token, decoded header, and each encoded segment. The generated API's embedded test returns the exact valid token string. |

Validation: eight TypeScript decoder tests and four real embedded-core token-result tests pass. The latter accelerate the fixture timer capability to exercise the existing bounded retry policy without waiting several minutes for repeated malformed responses; they do not change production delays. Existing packaged iOS/Android API proofs also continue to return the fixture token through generated `getToken`.

This is parsing and client-state preservation evidence, not JWT signature verification, backend acceptance, or signed-in app upgrade evidence. The old Swift parser test file is retired after these checks; session authorization/freshness/race suites remain for their own audits.
