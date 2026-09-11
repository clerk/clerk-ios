# Passkey assertion options

The shared mobile credential integration requires a nonempty string `rpId` for assertions. Missing, registration-style-only, empty, whitespace-only and non-string values fail with `invalid_credential_options` at `requestingAuthorization` before native presentation. No frontend-domain fallback is inferred.

Generated sign-in passkey calls preserve the server's credential order, transports, timeout and verification policy. Malformed credential IDs fail during shared preparation rather than silently filtering the list. `SignInPasskeyParams` exposes flow and immediate-credential preference; it has no credential-list override.

The packaged core is pinned to JavaScript revision `cba4fd161f0b1d80f48a9128d47a85c9a4ca0521`, bundle SHA-256 `25001603e9c152c6aaa2f8bad982bbab2a7da122efd6774df89518c809b131a5`. The generated public API is unchanged.

`PasskeyOptionsTests.swift` checks eight cases through the generated API and packaged JavaScriptCore. The valid request deliberately stops at fixture cancellation; invalid requests never reach the credential capability. Every case retains the original incomplete sign-in, has no selected session and sends no credential to the fixture backend. All eight pass on macOS and iOS Simulator 26.5. The full Swift suite passes 278 tests. [Saved result summaries](evidence/passkey-options/proof.json) record the exact source and bundle hashes and Simulator cases.

These checks validate the packaged SDK boundary with fixture HTTP, not a real passkey dialog or a live service.
