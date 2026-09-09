# HTTP assertion migration

Baseline: `02f98f89a19b6c079517c9aae07df7edd0e600e5`. This audit reads the assertions in `Tests/Networking/ClerkAPIClientTests.swift` (19 declarations), `Tests/Middleware/NetworkingPipelineResponseMiddlewareOrderTests.swift` (1), `Tests/Utils/HTTPURLResponseExtensionsTests.swift` (7), and `Tests/Utils/RetryingOperationTests.swift` (4). It does not claim that the old native request pipeline survives or that its entire state policy has replacement coverage.

## Retained platform execution

`NativeCoreContractTests/AppleHTTPCapabilityTests.swift` runs the production `AppleCapabilities.perform("http", ...)` through a URLSession with an injected URLProtocol. It checks GET/POST/PATCH/DELETE, query encoding preservation, exact request bytes, Authorization forwarding, cookie isolation, HTTP status/body/header delivery, multipart text and binary bytes, rejected origins and malformed headers, invalid UTF-8, network failure, and task cancellation. It also invokes the production redirect delegate to check its destination policy. The test does not contact a live server or prove OS redirect negotiation/TLS behavior.

The audit found and corrected two host defects:

- Redirect requests accepted URL user information although initial requests rejected it. Both paths now reject usernames/passwords.
- Swift's `String.contains("\r")` and `contains("\n")` both return false for the combined CRLF grapheme. An injected combined CRLF in a header name or value reached URLProtocol in the initial contract run. Header names/values and multipart content types now use a character-set check, which also rejects combined CRLF.

The session explicitly disables Foundation credential storage as well as cookie storage and URL caching. Its Authorization header is supplied by the core. The public initializer signature is unchanged; the internal configuration initializer exists to substitute the OS network boundary in these tests.

## Validation

The dedicated `NativeCoreContractTests` scheme passed 43 tests on macOS and 40 on
iOS Simulator, including all six HTTP tests on each platform. The macOS run also
emitted contacts/LinkServices XPC diagnostics from system frameworks; no test
failed. These are CLI/headless platform tests, not a live network or UI proof.

## Assertion dispositions

| Original assertions | Current owner and disposition |
| --- | --- |
| `getRequest`, `postRequest`, `patchRequest`, `deleteRequest`, `queryParameters` | URLSession transport checks preserve methods, query bytes and the core-supplied body. Form construction belongs to shared TypeScript, including its querystring suite. |
| `requestHeaders`, `mobileHeaderValueMatchesPlatform`, `isNativeQueryParameter` | TypeScript constructs Clerk API/client/native metadata. Native hosts pass the supplied values. The old `DependencyContainer` and its desktop/mobile header calculation are removed. The URLSession tests prove forwarding, not parity of every old header value; that remains a core integration audit. |
| `postRequestWithExplicitJSONContentType` | TypeScript owns JSON content selection and metadata serialization. The host forwards body strings verbatim. The old native `Encodable` request API is removed. |
| `multipartUpload` | The new test checks actual binary/text bytes and boundary headers, beyond the old assertion that only checked the content type. |
| `errorHandling` | The native HTTP capability returns 422 status, response body and normalized headers. TypeScript interprets API errors; the generated bridge lowers approved error envelopes. An HTTP 4xx is not itself a native network exception. |
| Failed/successful tokenless startup requests | Removed native startup refresh coordinator. Their required outcome—late startup cannot replace an established identity—belongs in the core identity/race audit and is not claimed covered by these host tests. Keep the old assertions until that audit is complete. |
| Frozen shared identity on retry; identity/device-token changes cancel retry; custom signing sees frozen values | Removed custom native middleware and shared-session context. The embedded core owns retries/credential epochs. Live shared-session synchronization is unavailable. Keep these assertions as evidence while the state audit is incomplete. |
| Deferred client sync metadata and disabled automatic sync | Removed native API surface. The two metadata objects have no new public equivalent. Core state and credentials must commit consistently; that outcome belongs in the core race audit. |
| Custom response middleware precedes built-in middleware | Custom native middleware is not retained. No replacement ordering API is claimed. |
| HTTP status range predicates, category enum and human-readable description | Removed convenience extensions. Raw HTTP statuses remain lossless; Clerk error semantics belong to TypeScript, not a second Swift category system. |
| Retrying operation succeeds after retry, stops at max attempts, sanitizes policy inputs, clamps exponential delay | Removed generic native retry utility and policy. Hosts execute one core-requested operation; Clerk retry behavior must be validated in TypeScript. No independent Swift retry algorithm is reintroduced. |

No old file is retired in this change: the mixed transport/state networking file still contains unresolved identity assertions. These tests do not replace live TLS, device network interruption, upload size/performance or backend auth checks. URLSession's existing 16 MiB response validation occurs after loading; it is a decoded-response limit, not a proven peak-memory bound.
