# Organizations

A signed-in user opens OrganizationSwitcher, creates an organization, and the new organization becomes the active one.

## Sub-features

- `create-from-switcher` creates an organization from the switcher's account list and makes it active.

## How to get to it (user POV)

- Tap OrganizationSwitcher, which reads `Personal account` while no organization is active.
- Tap `Create organization` in the account list, type a name, and submit.
- Skip the invite step.

## Driving it with verify

Preconditions:

- The standard settings have organizations on and let users create organizations.
- The spec seeds a user and signs in with a ticket and lands on the home, where the OrganizationSwitcher is.

- **Create.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run organizations`. The launch lands on the home with the user's email and user ID. The spec taps the switcher, which reads `Personal account` while no organization is active, taps `clerk.organization.accountList.createOrganization`, fills `clerk.organization.profileForm.name` with `Verify <runId>`, and taps `clerk.organization.profileForm.submit`.
- **Skip invites.** The spec taps `Skip` on the invite step, waits for the home to show the same user again, and expects the organization name on the switcher and no `Personal account`. Screenshot `org-created`.
- **Proof.** The screenshot shows the switcher with the new organization's name under the user's email.

## Gotchas

- The switcher label has no SDK identifier. The spec taps its visible text, `Personal account`.
- `host.expectSignedInAs` waits for the switcher's sheet to close.
- The invite step appears only when the organization allows more than one member. The standard settings allow three.
