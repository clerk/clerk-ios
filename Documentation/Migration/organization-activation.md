# Organization activation

An organization switch becomes observable after the server accepts the session touch. Previously, `Clerk.setActive` mutated `Session.lastActiveOrganizationId` before awaiting the request. A rejected switch left the Session pointing at the rejected organization while Clerk.organization still referred to the previous selection. Other calls could publish that inconsistent state while the request was pending.

The shared TypeScript implementation now carries the proposed organization as an internal request parameter. Session touch uses it in the HTTP body, then hydrates selection from the accepted response. It does not require rollback: an older rejected request cannot overwrite a newer accepted selection. Both ordinary touch and the internal navigation touch use this path. Explicit organization switches also perform this validation from an inactive browser tab.

Omitting organization preserves the existing selection; explicit null requests a personal account. Existing force-organization-selection policy still prevents a personal selection when required. The internal request parameter is excluded from the generated native public API. Swift and Kotlin do not implement separate selection logic.

## Evidence

- The regression failed against the previous packaged bundle in both native engines: rejected switches exposed the proposed organization. The Apple race case failed as well.
- Two canonical Session tests cover pending state, rejection, and hydration from an accepted response whose organization differs from the proposal. The relevant Clerk and Session source suites pass all 244 tests.
- Five embedded protocol cases cover rejection, accepted organization, personal account, omitted organization, and an older pending rejection after a newer successful switch. The full embedded suite passes 307 tests.
- Native SessionActivation tests exercise the generated public API, actual form parameters, observed roots, and the same pending/rejected request race through JavaScriptCore and QuickJS.

These are deterministic service fixtures. Live service acceptance and OS authentication flows remain separate verification gates. This change does not claim to complete the broader legacy SessionService token-cache and activation audit.

## Packaged verification

Both SDKs package core revision `3260b879799448630c20d459f207c3d0f78fc3ae`, bundle SHA-256 `3d5cb56dc9efa48e30b5280656f430dbf524bea874914a53826b2022627c07e0`, contract `d0e44f4d5307614738d237be8326540031290579f49e2b098be85596ced06d98`. The resulting full suites pass 79 Apple test declarations, 76 iOS Simulator test declarations, and 59 enabled Android instrumented cases. Two Android opt-in benchmark/live-service cases report unmet assumptions because their flags are absent; those gates were not exercised. All five Android activation cases and all three Apple activation declarations (including their parameter cases) pass. Reproducibility, native binding generation checks, attached Expo bundle checks, and runtime TypeScript checking pass. Native public API snapshots have no changes.

## Rejected authentication-status follow-up

The legacy session-service audit exposed a second rejection path: a 401 organization-switch response was swallowed by the general authentication-recovery handler, so `setActive` reported success. The generated embedded check and the old packaged JavaScriptCore check both failed with a missing rejection. Explicit organization requests now propagate the error through ordinary and navigation touch; background touches retain their existing recovery behavior. Native tests verify both 401 and 403, preserving the previous organization. Embedded checks also preserve the old template token after failure, separate template cache entries after an accepted switch, and enforce required organization selection without HTTP.

The updated package pins revision `ea3c1dd6d3ba43f411f2152566d35640a1038104`, bundle SHA-256 `48237898bd4e60de4ffb99c0a5d0c2a8bd06be8c322e2b5964ecbfab316a9d76`, with the same contract and native public signatures. Validation passes 143 source Clerk tests, 320 embedded tests, 79 macOS contract tests, 76 iOS Simulator contract tests, and all six Android activation cases. These counts include existing tests; the 401 case is an additional parameter case on Apple. Native generation and preview refresh succeeded during packaging. The shared mint/sign-out checks use embedded deterministic fixtures; they were not duplicated as new host tests or presented as live service evidence.
