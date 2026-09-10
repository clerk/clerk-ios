# Organization creation defaults assertion audit

All three declarations in baseline `Tests/Domains/Organization/OrganizationCreationDefaultsTests.swift` were read. The legacy decoder accepts a null form, an advisory without severity, and a form without a slug. The generated API follows the TypeScript resource's normalized form, so the first and third cases use empty strings rather than nullable legacy fields.

## Reproduced shared-resource defect

`User.getOrganizationCreationDefaults` rejected an advisory with `code` and `meta` but no `severity`: `invalid_projection:OrganizationCreationDefaults.advisory`. The failure reproduced in the embedded runtime, macOS JavaScriptCore, and Android QuickJS. Source testing also showed an undefined severity in the JavaScript resource and its snapshot.

This is a real response shape in the inspected backend, not an invented malformed fixture. At backend revision `33e0f8279c9b4e3d90d6e4788c67237bc6378a56`, [`api/serialize/organization_creation_defaults.go`](https://github.com/clerk/clerk_go/blob/33e0f8279c9b4e3d90d6e4788c67237bc6378a56/api/serialize/organization_creation_defaults.go#L71) defines the advisory response with `Code` and `Meta` and no severity. This is local source evidence; no live backend request was made.

The fix belongs in `clerk-js` resource hydration. The wire JSON type now permits missing severity, and the resource defaults it to the supported `warning` value. An explicitly supplied severity is preserved. The response object is not mutated; snapshots contain the normalized severity. The public native declaration remains the same, with no Swift/Kotlin fallback parser or optional-severity exception.

## Assertion map

| Old test | Generated behavior and evidence |
| --- | --- |
| `decodesNilForm` | Actual GET returns `advisory: null, form: null`. The generated resource has no advisory and a canonical empty form: empty name/slug, nil logo/blur hash. This intentionally replaces a nil native form. |
| `decodesAdvisoryWithoutSeverity` | Actual GET preserves advisory code, organization-domain metadata and form name. Severity becomes `warning` in the shared resource instead of a nil native field; previously this response could not cross the bridge. |
| `decodesFormWithoutSlug` | Actual GET preserves name and nil logo/blur hash, with the canonical empty slug. |

Each case runs in `organization-defaults.test.mjs`, Swift `OrganizationDefaultsTests.swift`, and Kotlin `OrganizationDefaultsTest.kt`. Source tests also check the missing/explicit severity cases and snapshot behavior. The legacy defaults decoder suite is retired after replacement validation. Separate Organization and OrganizationService suites remain retained.

## Validation

All 353 embedded tests and 39 source OrganizationCreationDefaults/Organization/User tests pass. Mobile-runtime type checking, generated-output verification, and reproducibility checks pass. The full native contract suites pass: 84 tests on macOS, 81 on iOS Simulator, and 78 deterministic Android cases. Android was run directly with `adb shell am instrument` after Gradle applied only the first class in a comma-separated filter; only the live-startup and benchmark opt-in classes were excluded. The source pin is `e7e04dc7237f2bd4badf6f6b756942530bf219f9`, contract `0f8387f260072ba6f894442b73d50afa6bda5f1205ed3c9209f5d6b1cfba16ce`, and byte-identical native bundle SHA-256 `fb59f237d749c72fffc1d8fde3b48458091b43bf4610e3d0b35f443d8cb87bbf`. Deterministic service fixtures do not establish live organization creation, old-major upgrades, or physical-device performance.
