# Organizations

A signed-in user opens OrganizationSwitcher, creates an organization, and the new organization becomes the active one. An app can also embed OrganizationListView in a tab, where it stays mounted while the user signs out, signs in, or switches accounts.

## Sub-features

- `create-from-switcher` creates an organization from the switcher's account list and makes it active.
- `embedded-account-list` keeps OrganizationListView mounted in a tab and shows only the signed-in user's organizations after an account switch and after a sign-out and a sign-in as another user.

## How to get to it (user POV)

- Tap OrganizationSwitcher, which reads `Personal account` while no organization is active.
- Tap `Create organization` in the account list, type a name, and submit.
- Skip the invite step.
- For the embedded list, tap `Organization tabs` on the home (`e2e.home.organizationTabs`). E2EHost shows a tab bar with `Home`, `Accounts`, and `Organization`. `Accounts` is `OrganizationListView(isDismissible: false)` and `Organization` is `OrganizationProfileView(isDismissible: false)`. `Home` is the home itself, with its sign-in and sign-out buttons.

## Driving it with verify

Preconditions:

- The standard settings have organizations on and let users create organizations.
- The spec seeds a user and signs in with a ticket and lands on the home, where the OrganizationSwitcher is.

- **Create.** Run `e2e-tests/bin/control-clerk-ios run organizations/create-from-switcher`. The launch lands on the home with the user's email and user ID. The spec taps the switcher, which reads `Personal account` while no organization is active, taps `clerk.organization.accountList.createOrganization`, fills `clerk.organization.profileForm.name` with `host.newOrganizationName()`, such as `Harbor 7c1e`, and taps `clerk.organization.profileForm.submit`.
- **Skip invites.** The spec taps `Skip` on the invite step, waits for the home to show the same user again, and expects the organization name on the switcher and no `Personal account`. Screenshot `org-created`.
- **Proof.** `specs/features/organizations/create-from-switcher.e2e.ts` passes, and the screenshot shows the switcher with the new organization's name under the user's email.
- **Embedded list.** Run `e2e-tests/bin/control-clerk-ios run organizations/embedded-account-list`. The spec seeds two users with an organization each, signs the first in with a ticket, opens `Organization tabs`, and expects the first user's organization on `Accounts` (`accounts-first-user`). It adds the second user from the UserButton's `Add account` with the email code, closes the profile, and expects only the second user's organization on `Accounts` (`accounts-after-switch`). It signs out from `Home`, signs the first user in through the `Sign in` sheet, and expects only the first user's organization (`accounts-after-sign-out-and-in`). It switches to `Home` and back and expects the rows again (`accounts-reappear`).

## Gotchas

- The switcher label has no SDK identifier. The spec taps its visible text, `Personal account`.
- `host.expectSignedInAs` waits for the home to show the user's email, user ID, and a session ID. The home is readable only once the switcher's sheet has closed, so the wait also covers the close.
- The invite step appears unless the organization allows exactly one member. A limit of 0 means no limit and shows the step too. The standard settings allow three.
- The slug of an organization comes from its name, and Clerk refuses a second organization with the same slug in the instance with "That slug is taken. Please try another." Every test in a run shares the run id, and so does every attempt of a test that `--retries` runs again. So each spec that creates an organization names it with `host.newOrganizationName()`, which claims a word for the run on this machine and adds the run tag, as `Harbor 7c1e`. No other test of the run and no retry gets that word, so a retry does not create the slug its first attempt took.
- The tab bar's buttons have the identifiers of their SF Symbols, `house`, `person.2`, and `building.2`. agent-device reports them as `button` on some reads and as `tab` on others, so the spec taps them by identifier.
- With an organization active, a tap on the switcher opens a sheet with `Manage` and `Switch account` instead of the account list. [Organization profile](./organization-profile.md) covers that sheet and the profile behind `Manage`.
