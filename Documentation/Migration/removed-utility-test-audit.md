# Removed proxy and logging helper assertions

This audit reads all sixteen tests in `Tests/Utils/ProxyConfigurationTests.swift` and all seven tests in `Tests/Logging/ClerkLoggerTests.swift`. Both files refer to APIs removed from the new major's supported configuration. Retiring them does not add proxy or custom logging support.

## Proxy configuration

The old helper's assertions cover valid scheme/host/path decomposition, nil and missing scheme/host rejection, port preservation, absent/root/multiple path segments, and prefixing empty/root/non-leading-slash/already-prefixed/partially matching paths. All sixteen describe the removed native `ProxyConfiguration` implementation. The current public `ClerkConfiguration` selects the publishable-key-derived FAPI and callback; it has no proxy option. Its four configuration tests validate those inputs, and the six Apple HTTP tests verify that a request cannot escape the allowed FAPI origin. They do not validate a proxy configuration path.

Proxy support remains explicitly unavailable in this prerelease profile. These helper assertions are retired with their absent configuration API, without keeping a second Swift URL-policy implementation just to compile the old tests.

## Logging configuration

The old tests assert default/error-level filtering, force-info accepting calls, comparison of two `.info` enum values, no error-handler callback for info, error level passing its configured threshold, and strict pre-installation cleanup delivering a keychain-error log to an explicit options handler. Several force/log tests merely call a method or check a synchronous flag without observing emitted logs; those assertions are not evidence of asynchronous log delivery.

The new SDK has no `Clerk.Options.logLevel`, `LogLevel`, `LogEntry`, custom logger callback, or global pre-installation configuration API. Its package-only `ClerkLogger` uses private OSLog interpolation; error propagation uses `CoreError`. Keychain read/write/clear failures are checked at the current storage boundary, and generated error propagation is checked through the packaged core. These checks do not preserve the removed custom log handler contract.

The old seven-test logging file is retired with those options. No output-capture test is added solely to mirror the private OSLog implementation. This audit does not claim that all production logging, crash diagnostics, or telemetry has undergone a separate security review.
