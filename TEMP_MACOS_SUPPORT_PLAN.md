# macOS Support Plan

## Current Step

The shared `UserButton` shell is now the source of truth on macOS too: [UserButton.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButton.swift), [UserButtonSignOutView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonSignOutView.swift), and [UserButtonAccountSwitcher.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonAccountSwitcher.swift) now keep the iOS session-task, profile-sheet, and sign-out flow as the source of truth instead of preserving a standalone macOS user-button shell. The auth boundary shift is now in the same state: [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) is the single public auth shell on both iOS and macOS again, [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) exists on macOS while keeping routing ownership in `AuthView`, and the temporary [AuthView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView+macOS.swift) scaffold is deleted instead of being preserved as alternate behavior. [AuthStartView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthStartView.swift), [SignInClientTrustView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInClientTrustView.swift), [SignInFactorCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorCodeView.swift), [SignInFactorOnePasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOnePasswordView.swift), [SignInFactorTwoBackupCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorTwoBackupCodeView.swift), [SignInSetNewPasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInSetNewPasswordView.swift), [SignUpCollectFieldView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCollectFieldView.swift), [SignUpCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCodeView.swift), [SignUpCompleteProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCompleteProfileView.swift), [SafariView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/SafariView.swift), [SessionTaskStartView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskStartView.swift), [SessionTaskMfaSetupView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaSetupView.swift), [SessionTaskMfaSmsChooseNumberView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaSmsChooseNumberView.swift), [SessionTaskMfaVerifySmsView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaVerifySmsView.swift), [SessionTaskMfaTotpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaTotpView.swift), [SessionTaskMfaVerifyTotpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaVerifyTotpView.swift), [SessionTaskBackupCodesView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskBackupCodesView.swift), [AuthState.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthState.swift), [LastUsedAuth.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/LastUsedAuth.swift), and [View+PreviewMocks.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/View+PreviewMocks.swift) now line up with that shared auth-shell direction on macOS too. macOS sign-up now reaches the shared collect-field, code, and complete-profile screens, and macOS session-task routing is now real for the shared `sessionTaskStart` shell, reset-password continuation, authenticator-app MFA continuation, and SMS MFA continuation through [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) and [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift). The next auth work is now fresh manual validation of the newly shared macOS session-task paths, plus the existing follow-up to decide whether macOS needs an equivalent to the iOS-only `.interactiveDismissDisabled(...)` guard in [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift).

## Status Key

- `[x]` complete
- `[>]` in progress
- `[ ]` not started

## Ordered Steps

1. `[x]` Add a native macOS example app that runs on `My Mac`.
2. `[x]` Give the macOS example app the basic entitlements it needs to make network requests.
3. `[x]` Fix shared auth presentation anchoring so web auth, passkeys, and Sign in with Apple use a real macOS window.
4. `[x]` Remove the smallest `ClerkKitUI` iOS-only gate so macOS can enter an auth flow from prebuilt UI.
5. `[x]` Validate the first end-to-end macOS sign-in flow in `MacExampleApp`.
6. `[x]` Audit and fix any additional macOS-specific auth flow issues found during manual testing.
7. `[x]` Review lifecycle handling on macOS and decide what behavior should be supported.
8. `[x]` Add macOS-focused smoke coverage for package build and example app build.
9. `[x]` Expand the full prebuilt macOS auth/profile surface until the current planned experience is manually validated.
10. `[>]` Merge back temporary macOS-specific implementation files into the shared component structure, starting with helpers and then moving up through row/section views and the remaining top-level user-button/auth shells.

## Current Known Gaps

- The macOS `AuthView` now uses the shared iOS-first auth shell, start screen, sign-in continuation path, sign-up flow, and the shared session-task reset-password, authenticator-app MFA, and SMS MFA paths. The remaining auth work is now fresh manual validation of those newly shared session-task paths plus any follow-up fixes found there.
- The shared `UserProfileView`, shared account switcher, and shared `UserButton` now run on macOS too, and the auth subtree no longer preserves a parallel macOS shell. The remaining convergence work is now mostly cleanup and validation rather than widening obviously iOS-only auth leafs.
- TODO: macOS now uses the shared session-task routing hooks in [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift); revisit whether macOS needs any equivalent to the still-iOS-only `.interactiveDismissDisabled(...)` protection once the MFA session-task subtree is widened.
- The macOS example app is still primarily a validation harness, even though it can now launch `AuthView()` and use `UserButton()`/`UserProfileView()`.
- `ClerkTheme` parity is materially better on macOS now that the current auth/profile surfaces use theme-backed input, section, loading/progress, and primary control chrome, but the remaining top-level convergence work is still structural rather than purely visual.
- TODO: add macOS profile image editing so [UserProfileUpdateProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileUpdateProfileView.swift) can match the existing iOS profile-photo flow more closely instead of leaving image editing iOS-only.
- Shared MFA sheet navigation now works on macOS too via [UserProfileNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileNavigation.swift); keep using that shared presentation model for follow-up MFA/security merge-backs instead of reintroducing local macOS sheet flags.

## Step 9 Capability Order

- `[x]` Connected accounts management
- `[x]` Profile editing
- `[x]` Password and security management
- `[x]` MFA and passkeys management
- `[x]` Account switching and multi-session flows
- `[x]` Delete account flow

## macOS File Inventory

- `[x]` [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift)
  Convergence result: the temporary [AuthView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView+macOS.swift) scaffold is deleted, and macOS now uses the shared public `AuthView` shell directly instead of preserving alternate top-level auth behavior.
- `[x]` [UserButton.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButton.swift)
  Convergence result: the temporary [UserButton+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButton+macOS.swift) scaffold is deleted, and macOS now uses the shared `UserButton`/`UserButtonSignOutView` session-task and profile-sheet flow directly.
- `[x]` [UserButtonAccountSwitcher.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonAccountSwitcher.swift)
  Convergence result: the temporary [UserButtonAccountSwitcher+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonAccountSwitcher+macOS.swift) scaffold is deleted, and macOS now uses the shared account-switcher list, add-account routing, and sign-out-all flow directly.
- `[x]` [UserProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileView.swift)
  Convergence result: the temporary [UserProfileView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileView+macOS.swift) scaffold is deleted, and macOS now uses the shared top-level profile shell, shared sheet navigation, and shared built-in router directly.
- `[x]` [UserProfileSecurityView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView.swift)
  Convergence result: the temporary [UserProfileSecurityView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView+macOS.swift) scaffold is deleted, and macOS now uses the shared security shell directly.
- `[x]` [UserProfileDeleteAccountConfirmationView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView.swift)
  Convergence result: the temporary [UserProfileDeleteAccountConfirmationView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView+macOS.swift) scaffold is deleted, and macOS now uses the shared destructive-confirmation shell directly.
- `[x]` [UserProfileMfaSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection.swift)
  Convergence result: the temporary [UserProfileMfaSection+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection+macOS.swift) scaffold is deleted, and macOS now uses the shared MFA section and row structure directly.

## Merge-Back Plan

- Goal: end with one public component surface per feature, not parallel iOS and macOS products.
- Hard rule: existing iOS behavior, logic, UI, and UX are the source of truth for macOS multiplatform support and for every merge-back.
- Hard rule: merge-back work must not change existing iOS behavior or UI unless we explicitly decide to change iOS first.
- Hard rule: the temporary `+macOS.swift` files were validation scaffolding, not product/source-of-truth implementations.
- Hard rule: do not preserve, port, or normalize behavior from temporary macOS validation files into shared production code unless iOS already behaves that way or a real macOS platform requirement forces the difference.
- Hard rule: when a temporary `+macOS.swift` file disagrees with iOS on layout, control placement, copy, validation, or interaction flow, assume the temporary macOS file is wrong by default and collapse back to the iOS behavior unless a concrete macOS API limitation requires the difference.
- Helper rule: before adding a macOS-only workaround branch in a shared file, first check whether the existing shared helper/modifier/preview utility can be widened to macOS quickly and safely; prefer widening helpers like `clerkPreview`, `onFirstAppear`, themed modifiers, and other lightweight utilities over scattering one-off call-site conditionals.
- Primary implementation rule: reuse the existing iOS component structure, UI layout, UX flow, and shared SwiftUI code wherever that is reasonably possible on macOS.
- Platform-specific code should be the exception, not the default:
  - add macOS-only code only when AppKit/macOS interaction differences actually require it
  - prefer widening existing components/helpers to multiplatform support over introducing new wrapper state, new view hierarchies, or alternate control patterns
  - when a shared iOS component already exists, the default question should be "how do we make this work on macOS?" not "should we write a separate macOS version?"
- Short-term rule: separate `+macOS.swift` files are acceptable only while feature coverage is still uneven and we are validating behavior quickly.
- Mid-term rule: once a macOS component reaches a stable minimum feature set, move shared business logic out of platform files first, then collapse the outer view shell.
- Merge order:
  1. Shared helpers and extensions
  2. Row/section subviews
  3. Modal/detail subviews
  4. Top-level public components
- UserProfile subtree merge status:
  - `UserProfileMfaSection+macOS.swift`, `UserProfileSecurityView+macOS.swift`, `UserProfileDeleteAccountConfirmationView+macOS.swift`, and `UserProfileView+macOS.swift` are all collapsed now; keep the shared files as the source of truth and clean up any drift there before adding new macOS-only behavior
- Auth subtree merge order from the leaves upward:
  - `AuthState.swift`
  - `AuthNavigation.swift`
  - `SignInClientTrustView.swift`
  - `AuthStartView.swift`
  - remaining auth leaf/detail/session-task views needed for real shared reuse
  - remove any remaining auth-only macOS scaffolding once the shared path is real
- Merge criteria before collapsing a file back:
  - the macOS feature is manually validated in `MacExampleApp`
  - the public API shape matches what iOS already exposes
  - shared async/business logic can live in one place without `#if` noise dominating the file
  - remaining platform differences are mostly layout/presentation, not capability gaps
- Preferred convergence shape:
  - one shared public type file when the body can stay readable
  - platform-specific private subviews or helper extensions inside the same file if the differences are small
  - separate helper files only for genuinely different platform chrome, not for duplicated business logic
- Convergence cleanup rule:
  - once a file is merged back, normalize shared state, naming, and async/business logic immediately where SwiftUI makes that practical
  - keep platform-specific branches for presentation chrome and platform-only APIs, not for duplicated state models like `isLoading` versus `isRevoking`
  - prefer reusing the existing iOS component structure, layout, and UX patterns unless macOS requires a genuinely different interaction model
  - preserve the iOS source-of-truth data choices and fallback behavior exactly, for example keeping `emailAddress` where the iOS row already uses `emailAddress` rather than introducing new display fields from the temporary macOS implementation
- What to avoid:
  - permanently keeping `AuthView`, `UserButton`, or `UserProfileView` split into unrelated iOS/macOS implementations
  - moving files back too early and creating dense `#if os(iOS) / os(macOS)` blocks before the shared boundaries are clear
  - letting platform-specific helpers leak into the public API
  - changing existing iOS behavior while trying to make macOS compile
- Current convergence priority:
  1. fix any merge-back drift that changed existing iOS behavior or UI
  2. widen `ClerkTheme` and related theme tokens to true multiplatform support, then replace remaining macOS system styling with theme-backed styling where appropriate
  3. collapse `UserProfile` modal/detail views
  4. collapse `UserProfileView`
  5. collapse `UserButton`
  6. collapse `AuthView`

## Working Notes

- Step 9 direction: continue expanding the prebuilt macOS auth UI surface rather than stopping at core-flow support.
- Step 9 first target: add a minimal macOS `UserButton` before attempting the much larger `UserProfileView` port.
- Step 4 approach: add a macOS-specific `AuthView` implementation in `ClerkKitUI` instead of trying to port the entire iOS auth UI stack in one pass.
- The first macOS `AuthView` should only expose SDK-backed entry points that already work on macOS, such as OAuth, Sign in with Apple, and other provider-based flows.
- `UserButton` and the broader signed-in profile UI remain later work. They are not required to validate the first macOS auth entry path.
- Step 4 result: `AuthView()` now builds on macOS and is wired into `MacExampleApp` as a sheet-based auth entry point.
- Architectural intent: the current macOS `AuthView` implementation is a stepping stone for validation, not the desired long-term split in public API.
- Long-term direction: keep a single public `AuthView` surface for consumers, while converging the underlying implementation into shared multiplatform behavior with platform-specific pieces only where needed.
- Validation after Step 4:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 5 result: the first end-to-end macOS sign-in flow was validated manually in `MacExampleApp` via Google OAuth.
- Step 6 focus: capture the next macOS-specific issues we hit during manual auth testing and tighten the SDK/UI behavior from there.
- Step 6 manual coverage target:
  - Sign in with Apple
  - Passkey sign-in, if enabled on the instance
  - At least one additional OAuth provider beyond Google, if enabled
  - Sign-out and re-auth behavior after a successful session
- Step 6 harness goal: keep `MacExampleApp` easy to use for repeated manual auth testing by exposing the active auth mode and visible auth options clearly.
- Step 6 harness update: `MacExampleApp` now shows the active `AuthView` mode, the currently visible providers from the loaded Clerk environment, and whether the passkey entry point should be available before opening the auth sheet.
- Validation after the Step 6 harness update:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 6 close-out: manual auth auditing is intentionally paused after the successful Google OAuth validation, and the plan is moving forward to platform hardening work.
- Step 7 focus: `LifecycleManager` currently skips macOS entirely, so native Mac apps do not trigger Clerk foreground/background handling at all.
- Step 7 decision: treat native macOS active/inactive transitions as the equivalent of the existing foreground/background lifecycle hooks.
- Step 7 result: `LifecycleManager` now observes `NSApplication.didBecomeActiveNotification` and `NSApplication.didResignActiveNotification` on macOS and routes them through the existing Clerk lifecycle callbacks.
- Validation after Step 7:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 8 result: macOS smoke coverage now exists as a dedicated `make smoke-macos` target plus a `shared-checks` workflow step that runs it in CI.
- Step 8 note: local sandboxing in this environment blocked the smoke target until it was verified once unrestricted. The target itself completed successfully end-to-end after that environment restriction was removed.
- Validation after Step 8:
  - `make smoke-macos` succeeded.
- Step 9 first milestone: `UserButton()` now has a minimal macOS implementation with a signed-in avatar button and a path back into `AuthView()` for pending session tasks.
- Step 9 harness update: `MacExampleApp` now uses `UserButton()` as the signed-in auth component instead of relying only on custom buttons.
- Validation after the Step 9 `UserButton` milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: sign in, view `UserButton`, open the macOS signed-in sheet, and sign out all worked in `MacExampleApp`.
- Step 9 second milestone: `UserProfileView()` now has a minimal macOS implementation and `UserButton()` presents that public profile component instead of a private temporary sheet.
- Validation after the Step 9 `UserProfileView` milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: tapping `UserButton()` opened the macOS `UserProfileView()` and showed the expected signed-in profile summary.
- Step 9 connected-accounts substep is complete and manually validated.
- Step 9 connected-accounts milestone: `UserProfileView()` on macOS now supports opening a connect-account sheet for unlinked providers and exposes reconnect/remove actions for existing connected accounts.
- Validation after the Step 9 connected-accounts milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: connected accounts render correctly, new accounts can be added, and an existing connected account can be removed from `UserProfileView()`.
- Step 9 next subtarget: profile editing inside macOS `UserProfileView()`.
- Step 9 profile-editing substep is complete and manually validated.
- Step 9 profile-editing scope: start with editable text fields that map to the existing user update APIs on macOS, and leave profile-photo management for a later pass if the text-editing flow lands cleanly first.
- Step 9 profile-editing milestone: `UserProfileView()` on macOS now exposes an `Edit Profile` entry point and presents a macOS `UserProfileUpdateProfileView()` sheet for username / first name / last name updates when those attributes are enabled for the instance.
- Validation after the Step 9 profile-editing milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: first name and last name can be edited successfully from the macOS profile editing flow.
- Step 9 next subtarget: password and security management inside macOS `UserProfileView()`.
- Step 9 password/security substep is complete and manually validated.
- Step 9 password/security scope: start with password management plus active device/session visibility on macOS, and leave MFA / passkeys / delete-account flows for their later dedicated steps.
- Step 9 password/security milestone: `UserProfileView()` on macOS now exposes a `Security` entry point and presents a macOS `UserProfileSecurityView()` with password add/change actions plus active-device session visibility and per-device sign-out.
- Validation after the Step 9 password/security milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: the `Security` sheet opens from `UserProfileView()`, password setup/change works, and active devices render correctly.
- Step 9 next subtarget: MFA and passkeys management inside macOS `UserProfileView()`.
- Step 9 MFA/passkeys substep is complete for the current scope.
- Step 9 MFA/passkeys scope: start with passkey add/rename/remove plus authenticator-app MFA and backup-code management on macOS; defer SMS-based MFA for a later pass.
- Step 9 MFA/passkeys milestone: `UserProfileSecurityView()` on macOS now includes passkey management plus authenticator-app MFA setup, disable, and backup-code viewing/regeneration.
- Validation after the Step 9 MFA/passkeys milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: authenticator-app MFA setup is working and the current macOS security flow looks acceptable for now.
  - Remaining note: passkey management UI is implemented but has not been manually exercised yet.
- Step 9 next subtarget: account switching and multi-session flows inside macOS `UserProfileView()`.
- Step 9 account-switching scope: add the iOS-equivalent multi-session entry points to macOS `UserProfileView()`, then use a dedicated macOS account-switcher sheet for active-session changes and sign-out-all while keeping the public surface area unchanged.
- Step 9 account-switching implementation note: macOS `UserProfileView()` now routes `Add Account` through `AuthView()`, presents a dedicated `UserButtonAccountSwitcher()` sheet for session changes, and narrows the main `Sign Out` button to the current session so multi-session behavior matches iOS more closely.
- Step 9 account-switching validation target: confirm that `Switch Account` appears when multiple sessions exist, that selecting another session updates the active account, that `Add Account` can open `AuthView()` from the session-management surface, and that `Sign Out All` clears every local session.
- Step 9 account-switching clarification: adding another login method for the same Clerk user is expected to show up under `Connected Accounts`, not as another switchable session. The switcher only becomes available after the client has more than one Clerk session for distinct signed-in users.
- Step 9 account-switching unblocker: the macOS `Add Account` flow now opens `AuthView(mode: .signIn)` and `AuthView()` now supports identifier/password sign-in so a second session can be created without relying on provider identities that may auto-link back to the current user.
- Step 9 account-switching current blocker: manual validation is still blocked when the second account requires `client trust` during password sign-in. The macOS continuation UI for the `needsClientTrust` state is not implemented yet, so the add-account flow can now surface the blocker clearly but cannot finish that path.
- Step 9 account-switching carry-forward note: revisit this substep after adding the macOS continuation UI for `needsClientTrust` and any other non-complete sign-in states that can appear in add-account flows.
- Step 9 next active subtarget: implement macOS client-trust continuation for the supported email-code and phone-code follow-up factors, then retry multi-session validation.
- Step 9 client-trust continuation milestone: macOS `AuthView()` now opens a focused verification sheet when password sign-in returns `needsClientTrust` with an email-code or phone-code follow-up factor, and that sheet can send/resend the code and attempt verification against the in-progress `SignIn`.
- Step 9 add-account provider follow-up: macOS `AuthView()` now routes OAuth and Apple results through the same sign-in/sign-up continuation handling as password auth, so a successful provider flow can refresh the client and activate a returned session instead of discarding the transfer-flow result.
- Step 9 add-account mode alignment: macOS `Add Account` now presents the default `AuthView()` mode, matching iOS account-switcher behavior, so provider-based add-account flows can transfer to sign-up when the selected identity does not already have a Clerk user yet.
- Validation after the Step 9 client-trust continuation milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 9 account-switching substep is complete and manually validated.
- Validation after the Step 9 account-switching milestone:
  - Manual validation succeeded: macOS `Add Account` can now add another account, and `Switch Account` works as expected.
- Step 9 delete-account scope: add a minimal destructive confirmation flow from macOS `UserProfileSecurityView()` using the same `type DELETE` safeguard as iOS, without coupling it to the blocked account-switching continuation work.
- Step 9 delete-account substep is complete and manually validated.
- Step 9 delete-account milestone: macOS `UserProfileSecurityView()` now exposes a guarded destructive flow that presents a dedicated confirmation sheet and requires typing `DELETE` before account deletion can proceed.
- Step 10 helper convergence pass is complete.
- Step 10 helper convergence result:
  - shared phone-number formatting helpers now live in [String+UIExt.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/String+UIExt.swift) for both iOS and macOS
  - shared relative-date formatting now lives in [Date+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Date+Ext.swift)
  - shared session formatting/device-description helpers now live in [Session+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Session+Ext.swift), with iOS-only `Text`/`Image` chrome kept conditional inside the same file
  - shared user/provider helpers now live in [User+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/User+Ext.swift)
  - the provider badge helper is now shared in [OAuthProviderBadgeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/OAuthProviderBadgeView.swift)
  - redundant helper-only files were deleted: `Date+macOSProfileExt.swift`, `Session+macOSProfileExt.swift`, `User+macOSProfileExt.swift`, and `OAuthProviderBadgeView+macOS.swift`
- Validation after the Step 10 helper convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 device row/section convergence pass is complete.
- Step 10 device row/section convergence result:
  - shared session sorting and visibility logic now live in [UserProfileDevicesSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDevicesSection.swift)
  - shared device revocation logic now lives in [UserProfileDeviceRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeviceRow.swift)
  - iOS and macOS now keep only the platform-specific layout and chrome branches inside those shared files
  - redundant row/section files were deleted: `UserProfileDevicesSection+macOS.swift` and `UserProfileDeviceRow+macOS.swift`
- Validation after the Step 10 device row/section convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 next subtarget: converge [UserProfileExternalAccountRow+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileExternalAccountRow+macOS.swift) back into [UserProfileExternalAccountRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileExternalAccountRow.swift), then revisit the connected-account modal/detail views that depend on that action model.
- Step 10 external-account row convergence pass is complete.
- Step 10 external-account row convergence result:
  - reconnect/remove logic now lives back in [UserProfileExternalAccountRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileExternalAccountRow.swift) for both platforms instead of being pushed up into the macOS profile shell
  - [UserProfileView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileView+macOS.swift) no longer owns row-specific reconnect/remove state
- Step 10 retroactive audit cleanup result:
  - [Session+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Session+Ext.swift) now uses the original iOS `browserFormatted`, `locationFormatted`, and `ipAndLocationFormatted` behavior on macOS too
  - the only remaining macOS-specific addition in that file is `deviceDescription`, because it does not exist on the original iOS implementation
- Step 10 second retroactive audit result:
  - re-audited the merged-back shared files against the original committed iOS implementations before starting `ClerkTheme`
  - fixed a second source-of-truth drift in [Session+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Session+Ext.swift) by restoring the original iOS `deviceText` empty-string behavior
  - fixed a second source-of-truth drift in [UserProfileExternalAccountRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileExternalAccountRow.swift) by restricting `refreshClient()` and `isUserCancelledError` handling back to macOS-only code paths so iOS behavior stays unchanged
  - no additional iOS-behavior drift was found in the previously merged-back helper, device-row/section, external-account-row, or shared utility files
- Follow-up note for later convergence:
  - [UserProfileExternalAccountRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileExternalAccountRow.swift) still has macOS-only `refreshClient()` and user-cancelled handling in reconnect/remove actions
  - those branches exist to compensate for current macOS profile-shell refresh and inline-error behavior, not because the shared row should permanently own different business logic
  - revisit and move that behavior upward when the macOS `UserProfileView` / connected-account flow is converged so the shared row can return closer to the original iOS action model
  - shared helpers used by the row were widened to multiplatform support where that was reasonable: [AsyncButton.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/AsyncButton.swift), [WrappingHStack.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/WrappingHStack.swift), [ProviderIconView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/ProviderIconView.swift), and [RemoveResource.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Utils/RemoveResource.swift)
  - the redundant row file was deleted: `UserProfileExternalAccountRow+macOS.swift`
- Step 10 drift cleanup note:
  - restore iOS source-of-truth behavior whenever a merge-back accidentally introduced data or fallback differences from the pre-existing iOS implementation
  - for [UserProfileExternalAccountRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileExternalAccountRow.swift), keep `emailAddress` as the row secondary value and restore the existing `#if DEBUG` fallback-image behavior instead of adopting the temporary macOS row defaults
- Step 10 retroactive audit result:
  - audited the earlier merge-back files against the committed iOS source-of-truth versions:
    - [UserProfileDeviceRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeviceRow.swift)
    - [UserProfileDevicesSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDevicesSection.swift)
    - [Session+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Session+Ext.swift)
    - [User+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/User+Ext.swift)
    - [String+UIExt.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/String+UIExt.swift)
    - [Date+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Date+Ext.swift)
  - fixed remaining iOS-behavior drift:
    - [UserProfileDeviceRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeviceRow.swift) now only clears the existing error pre-emptively on macOS, not on iOS
    - [Session+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Session+Ext.swift) now preserves the original iOS `browserFormatted`, `locationFormatted`, and `ipAndLocationFormatted` behavior exactly, while keeping the macOS-specific formatting behavior isolated to the macOS branch
  - no additional iOS drift was found in:
    - [UserProfileDevicesSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDevicesSection.swift)
    - [User+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/User+Ext.swift)
    - [String+UIExt.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/String+UIExt.swift)
    - [Date+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Date+Ext.swift)
- Validation after the Step 10 external-account row convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Validation after the Step 10 retroactive audit fixes:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 first `ClerkTheme` convergence pass is complete.
- Step 10 first `ClerkTheme` convergence result:
  - shared themed field/focus styling now works on macOS through [ClerkTextField.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/ClerkTextField.swift) and [ClerkFocusedBorder.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/ClerkFocusedBorder.swift)
  - current macOS auth/profile detail sheets now use the shared Clerk-themed text field instead of `.roundedBorder` where the shared input behavior already exists
  - current macOS profile/security `GroupBox` surfaces now use [ClerkGroupBoxStyle.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/ClerkGroupBoxStyle.swift) instead of the default system `GroupBox` chrome
- Step 10 cleanup note: after the first row/section merge, [UserProfileDeviceRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeviceRow.swift) was tightened so both platforms now share one `isLoading` state and one `error` source, with only the error presentation and control chrome staying platform-specific.
- Validation after the Step 10 first `ClerkTheme` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 second `ClerkTheme` convergence pass is complete.
- Step 10 second `ClerkTheme` convergence result:
  - current macOS auth/profile loading states now use [ClerkLoadingStatusView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/ClerkLoadingStatusView.swift) or [SpinnerView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/SpinnerView.swift) instead of the default macOS `ProgressView` chrome
  - current macOS cancel/close actions now use Clerk button styling instead of the default system button chrome
  - the macOS password-management toggle and passkey action menu label now pick up theme-backed control styling instead of reading as isolated system controls
- Validation after the Step 10 second `ClerkTheme` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfileUpdateProfileView` convergence pass is complete.
- Step 10 `UserProfileUpdateProfileView` convergence result:
  - the temporary [UserProfileUpdateProfileView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileUpdateProfileView+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfileUpdateProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileUpdateProfileView.swift)
  - shared profile-editing state, validation, and `User.UpdateParams` construction now live in one place, keeping the existing iOS flow as the source of truth
  - the shared view shell was tightened again after the initial merge so macOS now reuses the iOS-style `NavigationStack`, toolbar title/cancel placement, scroll layout, save-button placement, and shared error presentation instead of preserving the temporary macOS sheet copy and footer chrome
  - iOS-only profile photo editing stays isolated behind iOS conditionals, while macOS keeps only its sheet sizing and post-save `clerk.refreshClient()` behavior as platform-specific branches
  - TODO follow-up: port the existing iOS profile image editing flow to macOS rather than treating missing image editing as an acceptable long-term divergence
- Validation after the Step 10 `UserProfileUpdateProfileView` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfileChangePasswordView` convergence pass is complete.
- Step 10 `UserProfileChangePasswordView` convergence result:
  - the temporary [UserProfileChangePasswordView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfileChangePasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView.swift)
  - shared password-update state, validation, two-step navigation flow, and save handling now live in one place, keeping the existing iOS `UserProfileChangePasswordView` behavior as the source of truth
  - macOS now reuses the shared `NavigationStack`, toolbar title/cancel placement, shared error presentation, and sign-out-other-devices treatment instead of preserving the temporary single-form macOS sheet
  - the remaining platform-specific branches are limited to iOS-only compatibility helpers such as `hiddenTextField`, `preGlassSolidNavBar`, and `textInputAutocapitalization`, plus macOS sheet sizing
- Validation after the Step 10 `UserProfileChangePasswordView` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `BackupCodesView` convergence pass is complete.
- Step 10 `BackupCodesView` convergence result:
  - the temporary [BackupCodesView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/BackupCodesView+macOS.swift) scaffold was deleted, and both platforms now flow through [BackupCodesView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/BackupCodesView.swift)
  - shared backup-code instructions, grid layout, copy-to-clipboard action, and toolbar title now live in one place, keeping the existing iOS backup-code presentation as the source of truth
  - macOS now reuses the shared scroll/layout shell and themed toolbar instead of preserving the temporary standalone sheet, with only the iOS-only `UserProfileSheetNavigation` dismissal routing and the macOS toolbar-item placement staying platform-specific
- Validation after the Step 10 `BackupCodesView` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfilePasskeyRenameView` convergence pass is complete.
- Step 10 `UserProfilePasskeyRenameView` convergence result:
  - the temporary [UserProfilePasskeyRenameView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRenameView+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfilePasskeyRenameView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRenameView.swift)
  - shared passkey-name state, rename action, toolbar title/cancel placement, and error presentation now live in one place, keeping the existing iOS rename form as the source of truth
  - the remaining platform-specific branches are limited to the iOS-only `navigationBarTitleDisplayMode(.inline)` API and macOS sheet sizing
- Validation after the Step 10 `UserProfilePasskeyRenameView` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfilePasskeyRow` convergence pass is complete.
- Step 10 `UserProfilePasskeyRow` convergence result:
  - the temporary [UserProfilePasskeyRow+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRow+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfilePasskeyRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRow.swift)
  - shared passkey rename/remove state, confirmation-dialog flow, delete handling, and error presentation now live in one place, keeping the existing iOS row behavior as the source of truth instead of preserving the temporary macOS alert and refresh workaround
  - the remaining platform-specific branch is limited to the macOS `Menu` style compatibility needed to keep the shared ellipsis action label visually aligned
- Validation after the Step 10 `UserProfilePasskeyRow` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfilePasskeySection` convergence pass is complete.
- Step 10 `UserProfilePasskeySection` convergence result:
  - the temporary [UserProfilePasskeySection+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeySection+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfilePasskeySection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeySection.swift)
  - shared passkey sorting, add-passkey action, and section-level error presentation now live in one place, keeping the existing iOS section flow as the source of truth instead of preserving the temporary macOS `GroupBox` shell and refresh workaround
  - [UserProfileButtonRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileButtonRow.swift) and [UserProfileSectionHeader.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSectionHeader.swift) were widened so macOS can reuse the shared iOS row and section chrome directly
- Validation after the Step 10 `UserProfilePasskeySection` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfileMfaAddTotpView` convergence pass is complete.
- Step 10 `UserProfileMfaAddTotpView` convergence result:
  - the temporary [UserProfileMfaAddTotpView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaAddTotpView+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfileMfaAddTotpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaAddTotpView.swift)
  - shared authenticator-app secret/URI presentation, copy actions, verify navigation step, and backup-code follow-up now live in one place, keeping the existing iOS multi-step flow as the source of truth instead of preserving the temporary macOS inline verify form
  - [UserProfileVerifyView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileVerifyView.swift), [OTPField.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/OTPField.swift), [CodeVerificationStatusView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/CodeVerificationStatusView.swift), [CopyableTextView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/CopyableTextView.swift), [ContinueButtonLabelView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/ContinueButtonLabelView.swift), [TaskOnce.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/View+TaskOnce.swift), and [CodeLimiter.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Common/CodeLimiter.swift) were widened so the shared iOS verification stack can run on macOS too
  - follow-up cleanup: shared [UserProfileNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileNavigation.swift) now supports macOS too, so the temporary `closesPresentedMfaSheet`, optional `TOTPResource`, `taskOnce`, and backup-code completion escape-hatch cleanup should stay removed while [UserProfileMfaSection+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection+macOS.swift) collapses
- Validation after the Step 10 `UserProfileMfaAddTotpView` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 MFA navigation cleanup:
  - [UserProfileAddMfaView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileAddMfaView.swift) and [UserProfileNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileNavigation.swift) now support macOS presentation state for the shared add-MFA chooser and follow-up sheets, and [UserProfileSecurityView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView+macOS.swift) plus [UserProfileMfaSection+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection+macOS.swift) now route authenticator-app setup through that shared chooser flow instead of local standalone macOS sheet flags
  - [UserProfileMfaAddTotpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaAddTotpView.swift) and [BackupCodesView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/BackupCodesView.swift) keep the iOS-shaped `TOTPResource` input and shared dismissal flow, with the temporary `closesPresentedMfaSheet`, optional `TOTPResource`, `taskOnce`, and backup-code completion escape hatch removed
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 MFA SMS flow widening:
  - [UserProfileMfaAddSmsView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaAddSmsView.swift), [UserProfileAddPhoneView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileAddPhoneView.swift), and [ClerkPhoneNumberField.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/ClerkPhoneNumberField.swift) now support macOS so the shared add-MFA chooser can expose the same SMS path instead of hiding it behind a macOS-specific omission
  - shared phone-country parsing now uses a multiplatform lightweight helper in [PhoneNumber+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/PhoneNumber+Ext.swift) instead of depending on the iOS-only `CountryCodePickerViewController.Country` UI type from PhoneNumberKit
- Step 10 `UserProfileMfaSection` convergence pass is complete.
- Step 10 `UserProfileMfaSection` convergence result:
  - the temporary [UserProfileMfaSection+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfileMfaSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection.swift)
  - shared MFA method listing, default-phone ordering, add-MFA button routing, and section shell now live in one place, keeping the existing iOS section structure as the source of truth instead of preserving the temporary macOS `GroupBox` section
  - [UserProfileMfaRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaRow.swift) and [Badge.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/Badge.swift) were widened so macOS can reuse the shared row chrome, action menu, and default badge directly
- Validation after the Step 10 `UserProfileMfaSection` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfileSecurityView` convergence pass is complete.
- Step 10 `UserProfileSecurityView` convergence result:
  - the temporary [UserProfileSecurityView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfileSecurityView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView.swift)
  - the temporary [UserProfileDeleteAccountConfirmationView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView+macOS.swift) scaffold was deleted too, and both platforms now flow through [UserProfileDeleteAccountConfirmationView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView.swift)
  - shared password, MFA, passkey, devices, delete-account, and secured-by-footer sections now live under the same iOS-owned security screen structure, with only small platform-specific branches left for macOS sheet ownership, toolbar close affordance, and delete-completion behavior
  - [UserProfilePasswordSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasswordSection.swift), [UserProfileDeleteAccountSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountSection.swift), [UserProfileDevicesSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDevicesSection.swift), [UserProfileDeviceRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeviceRow.swift), [SecuredByClerkView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/SecuredByClerkView.swift), and [Session+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Session+Ext.swift) were widened so macOS can reuse the shared section and row structure directly
- Validation after the Step 10 `UserProfileSecurityView` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserProfileView` convergence pass is complete.
- Step 10 `UserProfileView` convergence result:
  - the temporary [UserProfileView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileView+macOS.swift) scaffold was deleted, and both platforms now flow through [UserProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileView.swift)
  - macOS now uses the shared top-level `UserProfileSheetNavigation`, `CodeLimiter`, and [UserProfileBuiltInRouter](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileNavigation.swift) model directly instead of local sheet booleans, so the temporary built-in-router guard stayed removed in [UserProfileDeleteAccountConfirmationView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView.swift)
  - [UserProfileDetailView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDetailView.swift), [UserProfileHeaderView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileHeaderView.swift), [UserProfileAddEmailView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileAddEmailView.swift), [UserProfileEmailRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileEmailRow.swift), [UserProfilePhoneRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePhoneRow.swift), and [DismissButton.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/DismissButton.swift) were widened so the existing iOS profile shell and manage-account destination can run on macOS too
  - follow-up cleanup: [UserProfileSecurityView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView.swift) now relies on shared environment navigation on both platforms instead of owning temporary macOS-local `sheetNavigation` and `codeLimiter` state, and its extra macOS-only `refreshClient()` workaround stayed removed
- Validation after the Step 10 `UserProfileView` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserButtonAccountSwitcher` convergence pass is complete.
- Step 10 `UserButtonAccountSwitcher` convergence result:
  - the temporary [UserButtonAccountSwitcher+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonAccountSwitcher+macOS.swift) scaffold was deleted, and both platforms now flow through [UserButtonAccountSwitcher.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonAccountSwitcher.swift)
  - shared session ordering, active-session switching, add-account routing, and sign-out-all behavior now live in one place, keeping the existing iOS list and navigation-driven sheet flow as the source of truth instead of preserving the temporary macOS card/footer shell and callback-based add-account path
  - [UserPreviewView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserPreviewView.swift) was widened so macOS can reuse the shared iOS user-preview row directly
- Validation after the Step 10 `UserButtonAccountSwitcher` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `UserButton` convergence pass is complete.
- Step 10 `UserButton` convergence result:
  - the temporary [UserButton+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButton+macOS.swift) scaffold was deleted, and both platforms now flow through [UserButton.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButton.swift)
  - macOS now uses the same iOS-owned session-task routing, profile-sheet presentation, and `UserButtonSignOutView` sign-out flow instead of preserving the temporary macOS-only presentation context and reduced sheet model
  - [UserButtonSignOutView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonSignOutView.swift) and [View+ContentSizingDetent.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/View+ContentSizingDetent.swift) were widened so the shared `UserButton` path can stay intact on macOS without adding one-off platform branches at the call site
- Validation after the Step 10 `UserButton` convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 auth-shell note: `AuthView` should be merged last, after the lower auth support stack and enough leaf/detail auth views are widened that the shared iOS shell can actually be reused instead of embedding a large macOS-only branch inside [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift).
- Step 10 auth support pass is complete.
- Step 10 auth support result:
  - [AuthState.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthState.swift) and [LastUsedAuth.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/LastUsedAuth.swift) now support macOS too, so shared auth identifier/persistence state and last-used-auth storage logic are no longer artificially iOS-only support types
  - [SignInClientTrustView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInClientTrustView.swift) was deliberately left iOS-only after review, because widening it before [SignInFactorCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorCodeView.swift) and [GetHelpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/GetHelpView.swift) would just force the macOS continuation UI to live as workaround state inside the shared file
  - [AuthIdentifierConfig.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthIdentifierConfig.swift) remains widened for both platforms so future shared auth-state wiring can reuse the same identifier configuration model
- Validation after the Step 10 auth support pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 `AuthNavigation` reassessment result:
  - do not widen [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) yet if doing so requires moving routing types or ownership out of [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) as a temporary workaround
  - revisit [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) only when the shared `AuthView` merge-back path is ready, or when a smaller support dependency can be widened without changing auth-shell ownership
- Step 10 helper prep pass is complete.
- Step 10 helper prep result:
  - the remaining small helper/view dependencies immediately below auth-start that were safe to widen without changing auth routing ownership now support macOS: [AppLogoView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/AppLogoView.swift), [HeaderView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/HeaderView.swift), [TextDivider.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/TextDivider.swift), [View+AppIcon.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/View+AppIcon.swift), and [View+DismissKeyboard.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/View+DismissKeyboard.swift)
  - a small set of lightweight auth support extensions are also widened for future incremental auth work without forcing shell/routing churn: [SignIn+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/SignIn+Ext.swift), [SignUp+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/SignUp+Ext.swift), [Factor+Sorting.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Factor+Sorting.swift), [Factor+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Factor+Ext.swift), and [Array+Ext.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/Array+Ext.swift)
- Validation after the Step 10 helper prep pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 auth helper/view pass is complete.
- Step 10 auth helper/view result:
  - [GetHelpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/GetHelpView.swift) now supports macOS too by switching its support-email action to shared SwiftUI `openURL` handling instead of the iOS-only `UIApplication` path
  - [IdentityPreviewView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/IdentityPreviewView.swift), [SessionTaskHeaderSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskHeaderSection.swift), and [StrategyOptionButton.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/StrategyOptionButton.swift) now support macOS too without changing auth routing or shell ownership
- Validation after the Step 10 auth helper/view pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 auth leaf prep pass is complete.
- Step 10 auth leaf prep result:
  - [SessionTaskAddPhoneForm.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskAddPhoneForm.swift) now supports macOS too, with its phone-entry field keeping the iOS number-pad keyboard hint conditional instead of introducing any platform wrapper
  - [LegalConsentView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/LegalConsentView.swift) now supports macOS too without changing its sign-up consent structure or link-handling behavior
  - audit result: [SessionTaskBackupCodesView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskBackupCodesView.swift) and [SignUpCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCodeView.swift) remain deferred because both still depend directly on the intentionally iOS-only [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift)
- Step 10 auth wrapper audit result:
  - [SignInFactorOneView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOneView.swift) is not a meaningful standalone widening target because its passkey, password, and code branches all immediately route into still-iOS-only sign-in factor views
  - keep thin wrapper views like [SignInFactorOneView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOneView.swift), [SignInFactorTwoView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorTwoView.swift), and [SessionTaskStartView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskStartView.swift) deferred until the factor/session-task children beneath them are actually shareable
- Step 10 auth shell merge-back pass is complete.
- Step 10 auth shell merge-back result:
  - [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) is now the single public `AuthView` definition on both iOS and macOS again, with routing ownership kept inside `AuthView`
  - [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) now exists on macOS too, with iOS-only destinations still gated where the downstream shared views are not ready yet
  - [View+PreviewMocks.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/View+PreviewMocks.swift) now injects `AuthState` and `AuthNavigation` on macOS previews as well
- Validation after the Step 10 auth shell merge-back pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 auth start/sign-in convergence pass is complete.
- Step 10 auth start/sign-in convergence result:
  - [AuthView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView+macOS.swift) was deleted instead of being kept as narrower alternate behavior, so macOS now uses the shared `AuthView` path directly
  - [AuthStartView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthStartView.swift) now supports macOS and remains the shared entry screen for the auth flow
  - shared sign-in continuations now build on macOS too: [SignInClientTrustView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInClientTrustView.swift), [SignInFactorAlternativeMethodsView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorAlternativeMethodsView.swift), [SignInFactorCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorCodeView.swift), [SignInFactorOneForgotPasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOneForgotPasswordView.swift), [SignInFactorOnePasskeyView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOnePasskeyView.swift), [SignInFactorOnePasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOnePasswordView.swift), [SignInFactorOneView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorOneView.swift), [SignInFactorTwoBackupCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorTwoBackupCodeView.swift), [SignInFactorTwoView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInFactorTwoView.swift), and [SignInSetNewPasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignIn/SignInSetNewPasswordView.swift)
  - macOS-only API differences inside the shared sign-in/start path stay narrowly conditional, such as keyboard-dismiss behavior, toolbar placement, and iOS-only text-input modifiers, instead of reintroducing an alternate macOS shell
  - follow-up: the shared [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) shell still keeps session-task presentation hooks under `#if os(iOS)` because macOS session-task routing is not implemented yet; revisit that gate once the session-task subtree is widened
- Validation after the Step 10 auth start/sign-in convergence pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 sign-up collect-field pass is complete.
- Step 10 sign-up collect-field result:
  - [SignUpCollectFieldView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCollectFieldView.swift) now builds on macOS too
  - [View+HiddenTextField.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Extensions/View+HiddenTextField.swift) now supports macOS too, so the shared username/password helper path stays aligned across auth and profile flows
  - the sign-up collect-field shell keeps only narrow platform guards for iOS-only keyboard and navigation-title APIs, instead of introducing a separate macOS sign-up wrapper
- Validation after the Step 10 sign-up collect-field pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 sign-up code pass is complete.
- Step 10 sign-up code result:
  - [SignUpCodeView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCodeView.swift) now builds on macOS too
  - the shared sign-up verification shell keeps only narrow platform guards for iOS-only keyboard-dismiss and navigation-title APIs, instead of preserving an iOS-only leaf
- Validation after the Step 10 sign-up code pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 sign-up routing pass is complete.
- Step 10 sign-up routing result:
  - [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) now routes macOS sign-up missing requirements into the shared collect-field and code screens instead of always falling back to `getHelp(.signUp)`
  - [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) now exposes those shared sign-up destinations on macOS too, while the session-task destinations remain deferred
  - that routing pass widened only the branches that had real downstream support at the time, with complete-profile convergence landing in the following pass
- Validation after the Step 10 sign-up routing pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 sign-up complete-profile pass is complete.
- Step 10 sign-up complete-profile result:
  - [SignUpCompleteProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SignUp/SignUpCompleteProfileView.swift) now builds on macOS too
  - [SafariView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Common/SafariView.swift) now supports macOS too, so the shared legal-consent links can keep the existing sheet-based flow instead of introducing a macOS-only escape hatch
  - [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) and [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) now expose and route the complete-profile destination on macOS too
  - the shared complete-profile shell keeps only narrow platform guards for iOS-only keyboard-dismiss and navigation-title APIs, instead of preserving an iOS-only leaf
- Validation after the Step 10 sign-up complete-profile pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 session-task start pass is complete.
- Step 10 session-task start result:
  - [SessionTaskStartView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskStartView.swift) now builds on macOS too
  - [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) and [AuthNavigation.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthNavigation.swift) now expose and route the shared `sessionTaskStart` destination on macOS too, so reset-password session tasks can use the real shared shell
  - macOS keeps `setupMfa` explicitly unsupported for now by landing on shared [GetHelpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/GetHelpView.swift) from [SessionTaskStartView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskStartView.swift) instead of pretending the MFA subtree is shared already
  - the shared auth shell now uses the existing session-task routing hooks on macOS too, while keeping `.interactiveDismissDisabled(...)` iOS-only
- Validation after the Step 10 session-task start pass:
  - `swift test --filter AuthNavigationTests` succeeded.
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 authenticator-app MFA session-task pass is complete.
- Step 10 authenticator-app MFA session-task result:
  - [SessionTaskMfaSetupView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaSetupView.swift) now builds on macOS too and exposes only the authenticator-app branch there, because SMS enrollment is still not shared
  - [SessionTaskMfaTotpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaTotpView.swift), [SessionTaskMfaVerifyTotpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaVerifyTotpView.swift), and [SessionTaskBackupCodesView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskBackupCodesView.swift) now build on macOS too
  - [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) now exposes the shared `taskMfaTotp`, `taskVerifyTotp`, and `backupCodes` destinations on macOS too, while leaving the SMS-specific session-task destinations deferred
  - clipboard behavior in the TOTP and backup-code screens now uses the same iOS/macOS split already used in the shared user-profile MFA flow instead of leaving UIKit-only clipboard calls in place
- Validation after the Step 10 authenticator-app MFA session-task pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 SMS MFA session-task pass is complete.
- Step 10 SMS MFA session-task result:
  - [SessionTaskStartView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskStartView.swift) now uses the shared [SessionTaskMfaSetupView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaSetupView.swift) on macOS too instead of falling back to [GetHelpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/GetHelpView.swift) for `setupMfa`
  - [SessionTaskMfaSetupView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaSetupView.swift), [SessionTaskMfaSmsChooseNumberView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaSmsChooseNumberView.swift), and [SessionTaskMfaVerifySmsView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/SessionTask/SessionTaskMfaVerifySmsView.swift) now build on macOS too
  - [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) now exposes the shared `taskMfaSmsChooseNumber` and `taskVerifySms` destinations on macOS too, so forced-MFA SMS enrollment no longer remains behind an iOS-only route gate
  - the shared SMS MFA shell keeps only narrow platform guards for iOS-only navigation-title and toolbar-placement APIs, instead of preserving an iOS-only branch for the flow
- Validation after the Step 10 SMS MFA session-task pass:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- Step 10 next subtarget: manually validate the newly shared macOS session-task MFA flows in `MacExampleApp`, then decide whether any remaining auth gaps still justify additional merge-back work before theme cleanup.
- Theme parity follow-up: after the modal/detail convergence work stabilizes, revisit [ClerkTheme.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkTheme.swift), [ClerkThemes.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkThemes.swift), [ClerkColors.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkColors.swift), [ClerkFonts.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkFonts.swift), and [ClerkDesign.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkDesign.swift) for any token-level cleanup that still makes sense once the shared view structure is settled.
- Validation after the Step 9 delete-account milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: the delete-account flow was exercised successfully from the macOS security UI.

## Notes

- Update the `Current Step` section first whenever we move to the next item.
- If a step turns out to be larger than expected, split it into smaller numbered steps instead of tracking it in prose.
