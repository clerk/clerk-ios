# macOS Support Plan

## Current Step

The `UserProfileUpdateProfileView` merge-back is complete: shared profile-editing state and update orchestration now live in [UserProfileUpdateProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileUpdateProfileView.swift), with only platform-specific presentation and APIs kept behind conditional branches. The next active subtarget is converging [UserProfileChangePasswordView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView+macOS.swift) back into [UserProfileChangePasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView.swift).

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
10. `[>]` Merge back temporary macOS-specific implementation files into the shared component structure, starting with helpers and then moving up through row/section views.

## Current Known Gaps

- The macOS `AuthView` is intentionally minimal. It now supports provider-based auth plus direct password sign-in, but it is still not feature-parity with the iOS auth stack.
- The macOS `UserProfileView` is now minimal, but the broader signed-in security/account-management surface is still iOS-only.
- The macOS example app is still primarily a validation harness, even though it can now launch `AuthView()` and use `UserButton()`/`UserProfileView()`.
- `ClerkTheme` parity is materially better on macOS now that the current auth/profile surfaces use theme-backed input, section, loading/progress, and primary control chrome, but the top-level public views are still split and the broader convergence work remains structural rather than purely visual.
- TODO: add macOS profile image editing so [UserProfileUpdateProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileUpdateProfileView.swift) can match the existing iOS profile-photo flow more closely instead of leaving image editing iOS-only.

## Step 9 Capability Order

- `[x]` Connected accounts management
- `[x]` Profile editing
- `[x]` Password and security management
- `[x]` MFA and passkeys management
- `[x]` Account switching and multi-session flows
- `[x]` Delete account flow

## macOS File Inventory

- `[ ]` [AuthView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView+macOS.swift)
  Target convergence: fold back into [AuthView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/Auth/AuthView.swift) behind one public `AuthView` surface, likely with shared top-level orchestration and platform-specific sections kept as private helpers or nested subviews.
- `[ ]` [UserButton+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButton+macOS.swift)
  Target convergence: fold back into the existing `UserButton` implementation so there is one public `UserButton` type with platform-specific presentation details hidden underneath.
- `[ ]` [UserButtonAccountSwitcher+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonAccountSwitcher+macOS.swift)
  Target convergence: merge into [UserButtonAccountSwitcher.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserButton/UserButtonAccountSwitcher.swift) after the shared session ordering, active-session selection, add-account routing, and sign-out-all behavior are aligned across platforms.
- `[ ]` [UserProfileView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileView+macOS.swift)
  Target convergence: merge back into [UserProfileView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileView.swift) once the macOS feature set is broad enough to justify a shared shell and shared navigation model.
- `[ ]` [UserProfileSecurityView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView+macOS.swift)
  Target convergence: merge into [UserProfileSecurityView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileSecurityView.swift) once the macOS security scope is closer to the iOS section set.
- `[ ]` [UserProfileDeleteAccountConfirmationView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView+macOS.swift)
  Target convergence: merge into [UserProfileDeleteAccountConfirmationView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileDeleteAccountConfirmationView.swift) after the destructive-action safeguards and any post-delete multi-session behavior are aligned across platforms.
- `[ ]` [UserProfileChangePasswordView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView+macOS.swift)
  Target convergence: merge into [UserProfileChangePasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView.swift) with shared password-update orchestration and platform-specific field/navigation layout.
- `[ ]` [BackupCodesView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/BackupCodesView+macOS.swift)
  Target convergence: merge into [BackupCodesView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/BackupCodesView.swift) once the dismissal and navigation behavior can be shared cleanly.
- `[ ]` [UserProfilePasskeySection+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeySection+macOS.swift)
  Target convergence: merge into [UserProfilePasskeySection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeySection.swift) with shared passkey CRUD orchestration and localized platform layout differences.
- `[ ]` [UserProfilePasskeyRow+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRow+macOS.swift)
  Target convergence: merge into [UserProfilePasskeyRow.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRow.swift) once rename/remove action wiring is shared.
- `[ ]` [UserProfilePasskeyRenameView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRenameView+macOS.swift)
  Target convergence: merge into [UserProfilePasskeyRenameView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfilePasskeyRenameView.swift) after converging on a shared rename form.
- `[ ]` [UserProfileMfaSection+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection+macOS.swift)
  Target convergence: merge into [UserProfileMfaSection.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaSection.swift) once the macOS MFA method set is closer to iOS and SMS support is no longer deferred.
- `[ ]` [UserProfileMfaAddTotpView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaAddTotpView+macOS.swift)
  Target convergence: merge into [UserProfileMfaAddTotpView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileMfaAddTotpView.swift) after the setup/verification flow is aligned across platforms.

## Merge-Back Plan

- Goal: end with one public component surface per feature, not parallel iOS and macOS products.
- Hard rule: existing iOS behavior, logic, UI, and UX are the source of truth for macOS multiplatform support and for every merge-back.
- Hard rule: merge-back work must not change existing iOS behavior or UI unless we explicitly decide to change iOS first.
- Hard rule: the temporary `+macOS.swift` files were validation scaffolding, not product/source-of-truth implementations.
- Hard rule: do not preserve, port, or normalize behavior from temporary macOS validation files into shared production code unless iOS already behaves that way or a real macOS platform requirement forces the difference.
- Hard rule: when a temporary `+macOS.swift` file disagrees with iOS on layout, control placement, copy, validation, or interaction flow, assume the temporary macOS file is wrong by default and collapse back to the iOS behavior unless a concrete macOS API limitation requires the difference.
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
- UserProfile subtree merge next:
  - `UserProfileChangePasswordView+macOS.swift`
  - `BackupCodesView+macOS.swift`
  - `UserProfilePasskeyRenameView+macOS.swift`
  - `UserProfilePasskeyRow+macOS.swift`
  - `UserProfilePasskeySection+macOS.swift`
  - `UserProfileMfaAddTotpView+macOS.swift`
  - `UserProfileMfaSection+macOS.swift`
  - `UserProfileSecurityView+macOS.swift`
  - `UserProfileDeleteAccountConfirmationView+macOS.swift`
  - `UserProfileView+macOS.swift`
- Top-level auth shell merge later:
  - `UserButtonAccountSwitcher+macOS.swift`
  - `UserButton+macOS.swift`
  - `AuthView+macOS.swift`
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
- Step 10 next subtarget: converge [UserProfileChangePasswordView+macOS.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView+macOS.swift) back into [UserProfileChangePasswordView.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Components/UserProfile/UserProfileChangePasswordView.swift), then continue through the remaining modal/detail views in merge order.
- Theme parity follow-up: after the modal/detail convergence work stabilizes, revisit [ClerkTheme.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkTheme.swift), [ClerkThemes.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkThemes.swift), [ClerkColors.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkColors.swift), [ClerkFonts.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkFonts.swift), and [ClerkDesign.swift](/Users/seanperez/Desktop/clerk-ios/Sources/ClerkKitUI/Theme/ClerkDesign.swift) for any token-level cleanup that still makes sense once the shared view structure is settled.
- Validation after the Step 9 delete-account milestone:
  - `swift build` succeeded.
  - `xcodebuild -project /Users/seanperez/Desktop/clerk-ios/Examples/MacExampleApp/MacExampleApp.xcodeproj -scheme MacExampleApp -destination 'platform=macOS' -derivedDataPath /tmp/MacExampleAppDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
  - Manual validation succeeded: the delete-account flow was exercised successfully from the macOS security UI.

## Notes

- Update the `Current Step` section first whenever we move to the next item.
- If a step turns out to be larger than expected, split it into smaller numbered steps instead of tracking it in prose.
