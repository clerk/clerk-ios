# User button and profile

A signed-in user opens their profile from UserButton, sees their own account, and can sign out or delete the account.

## Sub-features

- `user-button` opens UserProfileView for the signed-in user from the home UserButton.
- `add-account` opens AuthView from the profile's `Add account` row while the first session stays signed in.
- `sign-out` ends the session from the home screen.
- `sign-out-profile` ends the session from the profile's `Sign out` row.
- `delete-account` deletes the account from the profile's Security screen.

## How to get to it (user POV)

- Tap the avatar UserButton on the home screen.
- Tap `Sign out` on the home screen, or the `Sign out` row in the profile.
- Open the profile, tap `Security`, tap `Delete account`, type `DELETE`, and confirm.

## Driving it with verify

Preconditions:

- Each test seeds a `+clerk_test` user on the standard settings and signs in with a ticket on the home (`host.launch({ signedInAs })`). The launch lands when the home shows that user's email and user ID.

- **Profile.** Run `e2e-tests/bin/control-clerk-ios run user-button-and-profile`. The first test taps `clerk.userButton.profile`, expects `Edit profile` and `clerk.userProfile.currentUser.<userId>`, taps `clerk.userProfile.row.manageAccount`, and expects the user's email. Screenshots `user-button-profile` and `profile`.
- **Add account.** The second test opens the profile the same way, taps `clerk.userProfile.row.addAccount`, and expects `clerk.auth.start.identifier` in the sheet. Screenshot `add-account`.
- **Sign out.** The third test taps `e2e.auth.signOut` and waits for the home to show `Signed out` with no user ID and no session ID, then expects `e2e.auth.signIn`. Screenshot `signed-out`.
- **Sign out from the profile.** The fourth test opens the profile, taps `clerk.userProfile.row.signOut`, and waits for the same signed-out home. The profile's sheet closes when the user is gone.
- **Delete account.** Run `e2e-tests/bin/control-clerk-ios run user-button-and-profile/delete-account`. The spec launches with `authMode: 'signIn'`, opens the profile, taps `clerk.userProfile.row.security`, scrolls to `clerk.userProfile.security.deleteAccount` and taps it, types `DELETE` into the one text box of the confirmation sheet, and taps `clerk.userProfile.deleteAccount.confirm`. It waits for the home to show `Signed out`. It then opens the sign-in sheet, enters the deleted user's email, and expects `Couldn't find your account.`. Screenshot `account-deleted`.
- **Proof.** `specs/golden/user-button-and-profile/profile.e2e.ts` and `delete-account.e2e.ts` pass. The video shows the home name the seeded user before each test opens the profile, and `Signed out` after each sign-out.

## Gotchas

- A new application has reverification on, and the Platform API has no setting for it. Clerk accepts the deletion without another verification because the ticket sign-in happened seconds earlier. A spec that deletes the account long after its sign-in can be asked to verify again.
- `clerk.userProfile.deleteAccount.confirmation` matches two nodes, because the field takes focus as the sheet opens: the floating label and the text box. Wait on `.first()`, then fill `screen.getByRole('textbox')`.
- `Signed out` after a deletion looks the same as after a sign-out. The sign-in attempt with the deleted email is what shows that the account is gone. It needs `authMode: 'signIn'`, because the default mode would start a sign-up for an unknown email.
- A seeded user has no name, so the profile header shows only the avatar and `Edit profile`. The email appears under `Manage account`.
- The host shows a spinner while the ticket sign-in runs. `host.launch` returns once the home shows the user, and fails with the reason when the sign-in fails.
