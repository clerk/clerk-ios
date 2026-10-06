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

- The standard settings have organizations on and let users create organizations. The `settings` check of `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` compares the live instance with the standard file once the worktree holds an application.
- The spec seeds a user and signs in with a ticket on `screen: 'orgSwitcher'`.

- **Create.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run organizations`. The spec checks `orgId` null, taps `Personal account`, taps `clerk.organization.accountList.createOrganization`, fills `clerk.organization.profileForm.name` with `Verify <runId>`, and taps `clerk.organization.profileForm.submit`.
- **Skip invites.** The spec taps `Skip` on the invite step, waits for `orgId` to be non-null with the same `userId`, and expects the organization name on the switcher. Screenshot `org-created`.
- **Proof.** `states.jsonl` reports a non-null `orgId`. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` deletes the worktree's application, and the organization and its user go with it.

## Gotchas

- The switcher label has no SDK identifier. The spec taps its visible text, `Personal account`.
- `verify.state` is not readable while a sheet covers the host. Read state after the sheet closes.
- Use `host.tap` and `host.fill` inside the sheets, because of the iOS 27 `Toolbar` node.
- The invite step appears only when the organization allows more than one member. The standard settings allow three.
- `down` deletes the organization with the application it lives in, so a spec never deletes one itself.
