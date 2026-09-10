# Unused legacy test-support audit

After retiring the reviewed Clerk suite, all Swift sources in this worktree
were searched for the remaining JWT and generic test-helper entry points.
Neither file has a caller. Their full bodies were read and their bytes checked
against baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5` and the unchanged
[legacy inventory](legacy-tests.json).

| File | Lines | SHA-256 |
| --- | --- | --- |
| `Tests/TestSupport/TestHelpers.swift` | 181 | `08aff8951faa6385a86bad6a5e0bd603ea47b7c2161c24161b29dd77f0b37e57` |
| `Tests/TestSupport/JWTTestHelpers.swift` | 21 | `dd0f1aa9bde9c4eb3e30285935bc8702200ed63918bbcc306f936f2de9b38785` |

`TestHelpers.swift` contained the mock base URL/publishable key, direct native
client assignment, singleton configuration and mocked service-container setup,
legacy API-client construction, request-stream reading and JSON/form decoding.
Those helpers exercised removed native domain interfaces. The caller search
covered `mockBaseUrl`, `testPublishableKey`, `applyResponseClient`,
`configureClerkForTesting`, `setupMockAPIClient`, `createMockAPIClient`,
`urlEncodedFormBody`, `urlEncodedFormBodyMultiValue` and `jsonBody`.
Its private request-body accessor was used only by those local decoders.

`JWTTestHelpers.swift` contained `testJWT` and its private JSON/base64url encoder.
No current Swift source calls `testJWT`. The inventory's one function entry is
a helper, not a passing test or a removed public JWT contract; current JWT
behavior has its own [assertion audit](jwt-test-audit.md).

Only these two unused files are retired here. `InMemoryKeychain.swift` remained
at this stage because the shared-adoption suite still used its Keychain test types;
the [final adoption audit](shared-adoption-test-audit.md#final-retirement-decision)
subsequently retires both of those remaining files.
No test target, runtime implementation or shared fixture data is removed, and
no replacement test count is claimed for these helpers. The default test command
now runs the generated-core suite after completion of that final assertion audit.
