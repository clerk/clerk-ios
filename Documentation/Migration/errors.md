# Structured error continuity

Generated error-only authentication methods apply source state, then throw `CoreError` (Swift) or `CoreException` (Kotlin) when the returned Clerk error is non-null. Rejected promises, returned Clerk failures, bridge failures and caller cancellation retain separate kinds.

The infrastructure error exposes the source `code`, ordered `errors`, `status`, `retryAfter` (seconds), and `clerkTraceId`. Status, retry delay and trace ID are optional. Trace ID belongs to the response-level error, rather than being copied into every individual API error. Display text prefers the first API error's long message, then its short message, then the infrastructure fallback. The old native error constructors, Codable/Equatable contract, mutable localization/context helpers and native underlying error objects are not preserved by this new major.

The existing TypeScript request layer now carries `clerk_trace_id` from the API error payload into `ClerkAPIResponseError`. The bridge preserves its HTTP status and valid nonnegative retry delay. It continues to filter API metadata to the approved scalar fields (`paramName`, `sessionId`, `identifier`, `strategy`, `totalCount`); passwords and arbitrary response payloads do not become error details. Exposing retry metadata does not itself trigger a native retry.

Before the change, generated-protocol 422/429 tests reproduced missing status metadata. After the change, both pass with trace IDs, conditional Retry-After, multiple ordered errors and excluded password metadata. All 134 embedded tests and the existing two Base resource retry tests pass. Actual packaged-runtime tests pass on iOS Simulator and Android emulator and assert the thrown error's metadata, long-message preference and absence of the test password. The Android Gradle run reported a logcat-reader `java.io.IOException: Stream closed` after instrumentation; its XML reports four tests, zero failures/errors and no skips.

This verifies response-to-native error behavior using deterministic HTTP fixtures. It does not establish live server translations, application-specific localization, or successful authentication.
