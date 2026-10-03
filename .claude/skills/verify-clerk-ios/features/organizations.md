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

- `with-email-codes` has organizations on and lets users create organizations. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` checks that organizations are enabled.
- The spec seeds a user and signs in with a ticket on `screen: 'orgSwitcher'`.

- **Create.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run organizations`. The spec checks `orgId` null, taps `Personal account`, taps `clerk.organization.accountList.createOrganization`, fills `clerk.organization.profileForm.name` with `Verify <runId>`, and taps `clerk.organization.profileForm.submit`.
- **Skip invites.** The spec taps `Skip` on the invite step, waits for `orgId` to be non-null with the same `userId`, and expects the organization name on the switcher. Screenshot `org-created`.
- **Proof.** `states.jsonl` reports a non-null `orgId`. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down --dry-run` lists the organizations it will delete, and `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` deletes them with their user.

## Gotchas

- The switcher label has no SDK identifier. The spec taps its visible text, `Personal account`.
- `verify.state` is not readable while a sheet covers the host. Read state after the sheet closes.
- Use `host.tap` and `host.fill` inside the sheets, because of the iOS 27 `Toolbar` node.
- The invite step appears only when the organization allows more than one member. The `with-email-codes` default does.
- `down` finds the organizations a run created through the user that created them, deletes each one, then deletes the user. It counts organizations apart from users, and `down --dry-run` lists them. Never delete an organization by name.
