# Native Magic Link Investigation

## Context

This note summarizes the discussion about native email-link / magic-link behavior across:

- `clerk_go` open PRs
- Android implementation as of the April 15-16, 2026 commits
- current iOS implementation in this repo

The main question is whether backend semantics are changing from:

- "tap magic link and the backend finishes auth as a sign-in-ish flow"

to:

- "tap magic link, verify email ownership, then return the correct in-progress auth object (`SignIn` or `SignUp`) so the app can continue missing requirements / MFA / other next steps"

## Backend Direction From Open `clerk_go` PRs

The open PR stack indicates that native mobile magic links are moving to a PKCE-bound, multi-step flow:

- `#17993`: data layer for `magic_link_flows`
- `#17994`: `POST /v1/client/magic_links/start`
- `#17995`: `GET /v1/magic_links/verify`
- `#17996`: `POST /v1/client/magic_links/complete`
- `#18195`: native interstitial approval step
- `#18196`: support native sign-up email links
- `#18197`: support native sign-in email links, plus incomplete sign-up recovery fix

Important implications from the PR descriptions:

- Native mobile magic links are now flow-based, using:
  - `flow_id`
  - `approval_token`
  - `code_verifier`
- `#17996` explicitly says 2FA is respected.
  - `signInWithTicket()` may return `needs_second_factor`.
- `#18196` explicitly says native sign-up email links are supported.
  - This strongly suggests the callback may now complete into an in-progress `SignUp`, not only a `SignIn`.
- `#18197` explicitly mentions incomplete native sign-up recovery during app handoff.

## Android Findings

### Relevant Android Commits From April 15-16, 2026

Relevant:

- `d94bd523` `fix: align native magic link hooks with jdk 21`
- `0f4f9199` `fix(auth): resume email-link auth after app return`

Not relevant to iOS product behavior:

- `a779b700` JDK / sample / CI changes
- `3c6a0d86` formatting-only cleanup

### What Android Does Now

Android now treats magic-link completion as potentially returning either:

- `NativeMagicLinkAuthResult.SignIn`
- `NativeMagicLinkAuthResult.SignUp`

Android also explicitly allows completion to succeed when no `createdSessionId` exists yet:

- sign-in can return an in-progress `SignIn`
- sign-up can return an in-progress `SignUp`

That means Android supports flows such as:

- sign-in email link -> `needs_second_factor`
- sign-in email link -> `needs_new_password`
- sign-up email link -> `missing_requirements`

### Android App Return / Resume Behavior

Android does **not** auto-present `AuthView`.

What Android handles:

- recognize the callback link
- complete the callback
- update auth state
- if `AuthView` is shown, reroute from `currentSignIn` / `currentSignUp`

What Android does **not** handle automatically:

- deciding to present auth UI for the app

### If Auth Is Incomplete After Callback

If the callback completes but more steps are needed:

- Android stores the resulting auth attempt on `Clerk.client`
- `AuthView` resumes from `currentSignIn` / `currentSignUp`
- `AuthView` reroutes from the root auth screen into the correct next step

Examples:

- sign-in + MFA -> route to second factor
- sign-up + missing fields -> route to collect/verify missing requirements

### If the User Closes the App Before Tapping the Link

Android persists the pending native magic-link flow locally before opening Mail:

- PKCE verifier
- flow metadata
- TTL

If the app is closed and the user taps the link:

- deep link is recognized on cold start
- Android completes the callback using the persisted pending flow
- if auth is complete, session becomes active
- if auth is incomplete, the resulting `currentSignIn` / `currentSignUp` is available for `AuthView` to resume later

This means Android can recover the magic-link callback even on cold start, as long as the local pending flow and backend approval token are still valid.

## Current iOS Findings

### Current iOS Behavior

iOS currently assumes native magic-link completion is sign-in-only.

Current implementation:

- `Auth.handleMagicLinkCallback(_:)` returns `SignIn`
- `Auth.completeMagicLink(flowId:approvalToken:)` returns `SignIn`
- completion always exchanges the ticket through `signInWithTicket(...)`

iOS already has `signUpWithTicket(...)`, but native magic-link completion does not use it.

### Current iOS Status

The current iOS implementation now includes the lower-level UI-side primitives discussed earlier:

- callback-scoped continuation auth events:
  - `signInNeedsContinuation(signIn: SignIn)`
  - `signUpNeedsContinuation(signUp: SignUp)`
- `AuthView` continuation routing when auth UI is already visible
- startup session-task presentation support using a stored `AuthContinuation.sessionTasks`

Important current semantics:

- sign-in / sign-up continuation events are callback-scoped, not emitted for generic client refreshes
- `AuthView` does **not** generically resume `currentSignIn` / `currentSignUp` on ordinary app launch
- `AuthView` handles:
  - continuation routing once visible
  - session-task routing from current session state

### What iOS Already Has

- local pending PKCE storage for native magic links
- `AuthView` support for sign-up email-link verification UI
- app-level `clerk.handle(url)` API exists
- `AuthNavigation` can route a `SignIn` or `SignUp` to the correct next screen

### Gaps Between iOS and Android

#### 1. iOS Magic-Link Completion Is Still Sign-In Only

iOS still assumes:

- callback -> complete request -> ticket -> `signInWithTicket()`

That is incompatible with the backend direction shown by:

- `#18196` native sign-up email links
- `#18197` incomplete sign-up recovery

#### 2. iOS Does Not Resume In-Progress Auth From `AuthView`

This gap is now partially closed.

Current behavior:

- `AuthView` routes callback-scoped `SignIn` / `SignUp` continuation when auth UI is already visible
- `AuthView` routes pending session tasks from current session state

Remaining difference from Android:

- iOS does **not** yet complete native magic links into either `SignIn` or `SignUp`
- so the core callback result typing is still behind Android even though the UI-side resume plumbing now exists

#### 3. iOS Does Not Provide A Root-Level Prebuilt Presenter

This remains an intentional gap for now.

Current direction:

- `AuthView` is resumable once presented
- callback continuation is surfaced through auth events
- app hosts remain responsible for choosing when and how to present `AuthView`

#### 4. iOS Auth Events Are Completion-Only

This gap is now closed for callback continuation.

Current events:

- `signInNeedsContinuation(signIn: SignIn)`
- `signUpNeedsContinuation(signUp: SignUp)`

These are currently used as callback-scoped continuation events, not generic resumable-auth events.

## Product / API Conclusion

For now, the better tradeoff is to stop short of shipping a root-level prebuilt presenter.

Best direction:

- keep `AuthView` resumable once it is visible
- expose lower-level in-progress auth events for custom-flow and host-app users
- let app hosts own presentation policy (`sheet`, `fullScreenCover`, custom routing)

## API Design Direction Discussed

### Root-Level Presentation

We explored a root-level presenter API and decided not to ship it for now.

Reasoning:

- it pushes the SDK into owning presentation policy
- supporting both sheet-style and full-screen-style hosting expands the surface quickly
- hosts can implement the presentation glue themselves using `clerk.handle(url)`, startup checks, and continuation events

If a smaller host signal is needed later, it should stay non-UI.

### Explored Presenter Shapes

We explored several root-host API shapes before deciding not to ship one yet:

- a host modifier with host-level parameters
- optional binding-driven presentation control
- a concrete wrapper type to preserve auth-scoped chained modifiers

These ideas were workable, but they all came with the same cost:

- the SDK would end up owning presentation mechanics instead of just resumable auth state

### Why We Are Not Shipping A Presenter Type

We explored returning a concrete wrapper view and decided not to take that on.

Key reasons:

- it creates a long-lived public UI type for a thin convenience layer
- modifier ordering becomes part of the API contract
- presentation style and dismissal behavior become SDK responsibilities instead of host-app choices

- competing presentation paths
- unclear ownership of dismissal
- duplicate auth UI presentation possibilities
- more difficult docs, testing, and mental model

### Why We Are Not Shipping UI Helpers Yet

We also discussed narrower helpers, such as a deep-link-only modifier.

Conclusion:

- once a helper starts deciding whether to show auth UI, it effectively becomes a presenter
- that pushes the SDK back into owning presentation policy
- for now it is cleaner to stop at resumable state and continuation events

## Event Design Direction Discussed

### We Likely Need Lower-Level Auth Events For Manual / Custom Apps

Because hosts present `AuthView` themselves, they need a simple way to respond to incomplete auth that was recovered by the SDK.

We discussed using `AuthEvent` for this purpose.

### `signInStarted` / `signUpStarted` Is the Wrong Naming

We considered:

- `signInStarted(signIn: SignIn)`
- `signUpStarted(signUp: SignUp)`

Conclusion:

- these names sound like the user just initiated auth in the current app session
- they imply a button tap or explicit start action
- they do **not** clearly communicate "there is already an auth attempt in progress and the app should continue it"

### Better Event Naming: Continuation-Oriented

We discussed more continuation-oriented names and aligned on the idea that the event should express:

- auth exists
- auth is incomplete
- auth can continue if UI is presented

Current preferred naming direction:

- `signInNeedsContinuation(signIn: SignIn)`
- `signUpNeedsContinuation(signUp: SignUp)`

Why this is better:

- does not imply the user just started auth
- works for deep-link callback recovery
- works for resumed in-progress auth
- works for future continuation scenarios beyond magic links

### Role of the Continuation Events

The event should communicate auth state, not hardcode UI policy.

Meaning:

- SDK says: there is a resumable auth attempt
- app decides: present `AuthView` or otherwise continue that flow

This makes the event useful for custom apps while keeping prebuilt UI concerns inside the host modifier.

### Shared Responsibility Model: `AuthView` vs Host App

We discussed the case where:

- some apps present `AuthView` manually or use it as a root view
- auth UI may or may not already be visible when continuation is needed

Conclusion:

- both `AuthView` and the host app need to handle continuation-related behavior
- but they should own different responsibilities

Preferred split:

- `AuthView` owns continuation **routing**
- the host app owns auth UI **presentation**

#### `AuthView` Responsibilities

`AuthView` should handle continuation whenever auth UI is already visible, including:

- manually presented `AuthView`
- `AuthView` used as a root screen
- `AuthView` already presented by the host app

In those situations, `AuthView` should:

- inspect current auth state on appear
- listen for continuation events
- route to the correct next auth step

#### Host App Responsibilities

The host app should handle continuation whenever auth UI is **not** already visible.

In those situations, it should:

- listen for continuation events
- determine whether auth UI needs to be shown
- present `AuthView` if not already visible
- no-op if `AuthView` is already presented

#### Scenario Matrix

1. Manual or root `AuthView`, no host

- `AuthView` handles continuation itself

2. Host-managed presentation, `AuthView` not presented

- host app presents `AuthView`

3. Host-managed presentation, `AuthView` already presented

- `AuthView` routes itself
- host app does nothing

#### Recommended Shared Primitive

To avoid duplicating auth-state reasoning, both `AuthView` and host apps should be built on the same underlying continuation primitive.

That primitive should answer:

- is there resumable auth right now?
- is it a `SignIn` or `SignUp`?
- what auth step should continue?

Then:

- `AuthView` uses the primitive for navigation/routing
- host apps use the primitive for presentation decisions

## Proposed iOS Implementation Checklist

## Recommended Implementation Order

This is the suggested rollout order to minimize risk and build on stable primitives first.

### Phase 1: Add Continuation Auth Events

Status: complete

Add lower-level events such as:

- `signInNeedsContinuation(signIn: SignIn)`
- `signUpNeedsContinuation(signUp: SignUp)`

Why first:

- gives custom/manual apps a clean integration path
- provides the shared primitive needed by both `AuthView` and host apps
- provides the callback-scoped continuation events used by both manual apps and any future host integration

### Phase 2: Make `AuthView` Resumable

Status: complete

Teach `AuthView` to resume from:

- current auth state on appear
- continuation events while visible

Why second:

- manual/root `AuthView` must be able to recover on its own without a presenter
- `AuthView` must also handle the case where it is already presented by the host app
- startup session-task routing still needs to be driven from current session state once auth UI is visible

### Phase 3: Defer Root-Level Presentation API

Status: complete

Decision:

- do not ship a root-level prebuilt presenter yet
- keep the SDK focused on resumable auth state and events
- let hosts choose presentation policy

### Phase 4: Update Native Magic-Link Core for Sign-In + Sign-Up Continuation

Update iOS native magic-link completion to support:

- sign-in continuation
- sign-up continuation
- incomplete auth results with no immediate `createdSessionId`

Why fourth:

- highest-risk area
- most dependent on the evolving backend contract in open `clerk_go` PRs
- likely requires expanding pending-flow storage and result typing

### Summary of Recommended Order

1. continuation auth events
2. `AuthView` resume logic
3. defer root-level presentation API
4. native magic-link core parity updates

### Core Auth Changes

- [ ] Introduce a native magic-link auth result type that can represent either:
  - [ ] `SignIn`
  - [ ] `SignUp`
- [ ] Change `Auth.handleMagicLinkCallback(_:)` to support both sign-in and sign-up completion
- [ ] Change `Auth.completeMagicLink(flowId:approvalToken:)` to support both sign-in and sign-up completion
- [ ] Determine the correct ticket exchange path after `/magic_links/complete`:
  - [ ] `signInWithTicket(...)`
  - [ ] `signUpWithTicket(...)`
- [ ] Allow native magic-link completion to succeed when there is no `createdSessionId`
- [ ] Preserve current activation behavior when `createdSessionId` exists

### Pending Magic-Link Storage

- [ ] Expand iOS pending magic-link storage to include enough metadata for parity with Android
- [ ] Store pending flow state:
  - [ ] sign-in
  - [ ] sign-up
- [ ] Consider storing `flowId` as part of the pending flow
- [ ] Keep TTL / stale-flow handling explicit

### Auth Events

- [x] Add iOS auth events for incomplete but resumable auth attempts
- [x] Add `signInNeedsContinuation(signIn: SignIn)`
- [x] Add `signUpNeedsContinuation(signUp: SignUp)`
- [x] Ensure naming communicates continuation, not initial user-started auth
- [x] Scope current event emission to callback-driven continuation rather than generic client refreshes

### `AuthView` Resume Logic

- [x] Add `AuthView` listeners for continuation events while auth UI is visible
- [x] Re-run continuation resume logic on:
  - [x] initial appear
  - [x] continuation events
- [x] Keep `AuthView` self-sufficient so manual/root presentations work without any SDK-owned presenter
- [x] Keep session-task routing driven by current session state
- [ ] Revisit whether iOS should ever resume generic `currentSignIn` / `currentSignUp` on appear outside callback-scoped continuation

### Prebuilt UI Root Integration

- [x] Keep root-level presentation policy out of `ClerkKitUI` for now
- [x] Keep `AuthView` resumable once it is presented
- [x] Keep callback-scoped continuation events available to hosts
- [x] Add a small non-UI host signal:
  - [x] `Clerk.authPresentationRequirement`
  - [x] `View.onAuthPresentationRequirement(...)`

### Presentation Behavior

- [x] Define the prebuilt behavior when a callback finishes into:
  - [x] active session
  - [x] pending session task
  - [x] in-progress sign-in
  - [x] in-progress sign-up
- [x] Ensure prebuilt UI can present `AuthView` after a cold-start callback if additional auth work is required
- [x] Ensure `AuthView` dismisses normally when auth is truly complete

### Sign-Up Flow Parity

- [ ] Confirm sign-up email-link behavior against the backend contract from `#18196`
- [ ] Ensure sign-up email-link can return to the app as email verification, not forced full completion
- [ ] Route incomplete `SignUp` objects through existing `AuthNavigation` missing-requirements flow

### Sign-In Flow Parity

- [ ] Confirm sign-in email-link behavior against the backend contract from `#17996` and `#18197`
- [ ] Ensure sign-in email-link can return:
  - [ ] `needs_second_factor`
  - [ ] `needs_new_password`
  - [ ] `needs_client_trust`
- [ ] Route those states through existing `AuthNavigation`

### Tests To Add

- [ ] Native magic-link completion returns in-progress `SignIn` without session activation
- [ ] Native magic-link completion returns in-progress `SignUp` without session activation
- [ ] Native sign-up email-link callback uses sign-up ticket path
- [ ] `AuthView` resumes pending sign-in from auth root
- [ ] `AuthView` resumes pending sign-up from auth root
- [ ] `AuthView` does not reroute when already deeper in the auth stack
- [ ] Cold-start callback path can present/resume prebuilt auth correctly
- [ ] Pending flow survives app termination when required
- [ ] Stale pending flow is handled safely

## Practical Recommendation

If the goal is to match Android and keep iOS prebuilt UI easy to integrate, the target end state should be:

- host-controlled presentation for auth UI
- no SDK-owned opinion about sheet vs full screen
- SDK still handles callback recognition and auth resumption plumbing
- hosts can opt into a small presentation trigger API via `onAuthPresentationRequirement(...)`
- `AuthView` handles the actual next-step routing once shown
- custom flows can still listen to lower-level continuation auth events when they need more control

## Short Summary

iOS UI-side parity has mostly landed:

- callback-scoped continuation events exist
- `AuthView` can resume callback continuation and route session tasks when visible
- host apps remain responsible for presenting `AuthView`
- hosts can observe `authPresentationRequirement` / `onAuthPresentationRequirement(...)` instead of owning raw auth-event wiring

The main remaining parity gap is still core native magic-link completion:

- native magic-link completion is still sign-in-only
- iOS still needs a result type that can represent either `SignIn` or `SignUp`
- incomplete native sign-up recovery is still pending phase 4 work
