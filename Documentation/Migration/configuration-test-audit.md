# Configuration assertion audit

Reviewed all declarations and assertion bodies in the old
`Tests/Configuration/{ClerkOptionsTests,ConfigurationManagerTests,RedirectConfigTests}.swift`
at baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`.

| Old assertions | Current disposition |
| --- | --- |
| Valid test/live publishable keys, frontend URL extraction, and surrounding whitespace normalization | `ClerkConfigurationTests.validKeysNormalizeWhitespaceAndPreserveTheConfiguredCallback` checks both prefixes, the normalized key and exact HTTPS origin. The old `ConfigurationManager.instanceType` property is removed; instance mode is core-owned. |
| Empty/whitespace-only keys, invalid prefix/format, invalid base64 | `invalidPublishableKeysProduceStructuredErrors` rejects each case with `CoreError.code == invalid_publishable_key`. Old per-case initialization error enums are intentionally replaced by the shared error policy. |
| Default options, partial/custom options, property access | `Clerk.Options` is removed. The new immutable `ClerkConfiguration` requires a key and explicit callback URL. There is no promise to preserve the old native logging/telemetry option fields or their defaults. |
| Default/custom keychain service and access group | The old option structure is removed. `LegacyKeychainConfiguration` carries the old service/access group/key when importing credentials. New storage is application/key scoped. Storage migration and access-group execution require the separate credential audit; merely checking configuration values does not prove continuity. |
| All five `proxyUrlConversion*` tests, proxy options, `testUpdateProxyUrl`, `updateProxyUrlToNil`, `proxyConfigurationFromOptions` | Proxy configuration is explicitly unavailable in this prerelease. These assertions describe that unsupported feature, not passing replacement coverage. |
| `testUpdateFrontendApiUrl` | In-place mutation is intentionally unavailable. A core owner is bound to a validated publishable key/origin; applications close it and connect a new owner to change instance. |
| Request/response middleware initialization | The removed `Clerk.Options.middleware` arrays are not the new customization boundary. Applications may supply `NativeCapabilities`; domain request construction and response interpretation remain in TypeScript. The two array-count/type assertions retire with the old options API. |
| Default redirect URL/scheme and initialization with only one override | No implicit bundle-ID route or independently configurable scheme exists in the new configuration. The application supplies one full callback URL, preventing mismatched URL/scheme configuration. |
| Custom redirect URL and scheme, property access | The configured full URL is preserved by the new valid-key test. The browser presenter derives its scheme or verified HTTPS host/path from that URL. Invalid schemes, credentials and fragments are explicitly rejected by the new callback tests; HTTPS remains subject to platform support. |
| Shared-session synchronization default/enabled option | The old option is absent. Shared-session/watch replication remains an explicit prerelease limitation and a separate release gate. |

The four configuration test declarations pass against the generated-core package.
Additional malformed-key cases include a prefixless encoded host, a decoded
single character, and a host ending in `x` instead of `$`, matching intentionally
tightened behavior identified while reviewing the Android helper tests. Old
configuration test files are retired after this assertion review and passing current configuration checks. The separate [owner replacement audit](reconfiguration-test-audit.md) records the removed global reconfiguration contract. Storage, startup and identity outcomes have separate audits and release gates.
