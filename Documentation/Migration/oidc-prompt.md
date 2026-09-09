# OIDC prompt parameter

Generated `SignInSSOParams` and `SignUpSSOParams` expose `oidcPrompt` as the canonical TypeScript string. Pass a space-separated value such as `login consent` when required by the provider. The new API does not include the old Swift `[OIDCPrompt].serializedPrompt` helper or deduplicate a caller's string. Omit the optional parameter to omit it from the request. Explicit strings, including `none login` or duplicate tokens, remain the caller's values.

The audit of all six old Swift helper tests reproduced a shared-core bug: new future-style OAuth sign-in omitted this parameter while sign-up preserved it. The fix forwards the existing SSO parameter into the TypeScript sign-in creation path. No handwritten native request rule was added.

The 12 generated SSO tests pass, with separate sign-in/sign-up loops for omitted prompt, each old single value (`none`, `consent`, `login`, `select_account`), combined values, duplicates and `none` combined with another value. The 106 source sign-in tests pass. Packaged-core proofs on iOS Simulator and Android emulator also verify generated prompt parameters appear in their actual outgoing preparation requests. Provider-specific interpretation of a prompt is not simulated.

The reviewed `OIDCPromptTests.swift` file can retire with the deleted array helper: empty-array-to-nil maps to omitted string; single values and space-separated values are checked through the core; array deduplication is deliberately no longer an SDK operation. This does not change the native browser/credential presentation or claim a live provider sign-in.
