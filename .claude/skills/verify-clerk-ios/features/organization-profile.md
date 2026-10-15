# Organization profile

A member of the active organization opens its profile from OrganizationSwitcher, renames the organization, sees its members, invites people, reaches its verified domains, and can leave or delete the organization. Which rows, tabs, and buttons show depends on the member's permissions in the organization and on the instance's settings.

## Sub-features

- `profile` shows the creator every row of the profile: `Update profile` under the organization's name, `Members`, `Verified domains`, `Leave organization`, and `Delete organization`. `Members` shows the creator, marked `You`, on the `Members` tab, `No invitations sent` on `Invitations`, `No membership requests` on `Requests`, and `No members found` for a search that matches no one. `Verified domains` shows the `Add domain` row and no `No verified domains`. `Leave organization` asks the user to type the organization's name. `Delete organization` deletes it after the user types the name, and the switcher reads `Personal account` again.
- `invitation-sent` sends an invitation to a new `+clerk_test` address from `Invite` on the Members screen, and the address shows on the `Invitations` tab.
- `rename` changes the organization's name on `Update profile`, and the profile shows the new name.

## How to get to it (user POV)

- With an organization active, the OrganizationSwitcher on the home shows the organization's name. Tap it. A sheet titled `Organization` shows the name, the user's role, `Manage`, and `Switch account`. Tap `Manage`. The profile opens in a sheet titled `Organization`.
- From the profile, tap `Update profile`, `Members`, `Verified domains`, `Leave organization`, or `Delete organization`. On the Members screen, the three tabs are at the top and `Invite` is at the top right.

## Driving it with verify

Preconditions:

- Each test seeds a `+clerk_test` user on the standard settings, signs in with a ticket, and creates an organization from the switcher with `openNewOrganizationProfile` in the spec file, which then opens `Manage`. The user who creates an organization holds the `org:admin` role (`creator_role` in `src/core/instances/base.json`), which has every permission. The standard settings turn on domains, allow three members, and let an admin delete the organization.

- **Profile.** Run `e2e-tests/bin/control-clerk-ios run organization-profile`. The first test expects the five rows and takes screenshot `org-profile`. It opens `Members`, expects `You`, the user's email, and `Invite`, and takes screenshot `org-members`. It selects `Invitations` and expects `No invitations sent` (`org-invitations-empty`), selects `Requests` and expects `No membership requests` (`org-requests-empty`), selects `Members` again, types a name that matches no one into the search field, and expects `No members found` (`org-members-no-match`). It goes back, opens `Verified domains`, expects `Add domain` and no `No verified domains` (`org-domains`), and goes back. It opens `Update profile` and expects `clerk.organization.profileForm.name` (`org-update-profile`), then cancels. It opens `Leave organization`, expects `Type "<name>" below to continue.` (`org-leave-confirmation`), and cancels. It opens `Delete organization`, types the name, and confirms (`org-delete-confirmation`). The home then shows the same user and `Personal account`, with no organization name (`org-deleted`).
- **Invitation.** The second test opens `Members`, taps `Invite`, fills `Enter email addresses` with `host.newEmail()`, taps `Send invitations`, selects `Invitations`, and expects the address. Screenshot `invitation-sent`.
- **Rename.** The third test taps `Update profile`, clears `clerk.organization.profileForm.name`, fills it with `Renamed <runId>`, and taps `clerk.organization.profileForm.submit`. It expects the form gone and the new name on the profile. Screenshot `org-renamed`.
- **Proof.** `specs/features/organization-profile/organization-profile.e2e.ts` passes, and the screenshots show each screen with the organization's name or the creator's email. `down` deletes the application, and every organization and invitation goes with it.

## States a spec cannot reach

The harness seeds users only. It cannot seed an organization, a membership, a role, or a custom role, and a spec signs in one user per launch. The creator of an organization is its only member and an admin, so these states are out of reach on the standard settings:

| State | Where the app decides | What it takes |
| --- | --- | --- |
| `No verified domains` on Verified domains | `OrganizationVerifiedDomainsView.swift`: no domains and the member cannot manage domains | A member whose role has `org:sys_domains:read` without `org:sys_domains:manage`. An admin sees `Add domain` instead. |
| The `Members` row hidden | `OrganizationProfileView.swift`, `profileRows` | A member who can neither read nor manage memberships. Without the row, the profile never opens the Members screen, so the Members screen has no state with no tab. |
| The Members screen with one tab, no tab picker, no `Invite`, and no row menu | `OrganizationMembersView.swift`, `availableTabs` | A member who can read memberships but not manage them. A member who can manage but not read them opens on `Invitations`. |
| `Update profile` or `Delete organization` hidden | `OrganizationProfileView.swift`, `showsUpdateProfile` and `OrganizationProfileRow.actionRows` | A member without `org:sys_profile:manage`, or without `org:sys_profile:delete`. |
| Another member's row, `Change role` and `Remove member` on it | `OrganizationMembersRows.swift` | A second member in the organization. The creator's own row has the menu, and `Remove member` is off there. |
| A non-empty `Requests` tab | `OrganizationMembershipRequestsTabView.swift` | A verified domain with automatic suggestions and another user who asks to join. |
| The role-set warning on Members and on Invite | `OrganizationMembersTabView.swift`, `OrganizationInviteMembersView.swift` | An instance that is moving its organizations to another role set. |

These states need other settings, which a spec file can declare, and no spec drives them yet. With `domains_enabled` off, the profile has no `Verified domains` row and Members has no `Requests` tab. An organization created while `admin_delete_enabled` is off has no `Delete organization` row. `Invite` is off once the members and the pending invitations reach `max_allowed_memberships`, which is three on the standard settings, so two invitations turn it off.

A change to a state that no spec can reach is shown today on a build with a local change that is not part of the pull request, and the pull request says so. For example, returning `false` from `canManageDomains` in `OrganizationVerifiedDomainsView.swift` shows `No verified domains` to the creator. Name the change and the screens it affects in the pull request, and keep the spec in `specs/explored/`.

## Gotchas

- No row, tab, or button of the profile has an identifier except the name, slug, and submit of `Update profile`, which share the `clerk.organization.profileForm.*` identifiers with the create form. The spec finds rows and buttons with `getByRole('button', { name })` and tabs with `getByRole('tab', { name })`. `Members` is a row, a tab, and the title of the Members screen.
- `screen` prints each tab of the Members screen as a `button`, but a locator matches it only as a `tab`. The tree on a failure page shows the role that a locator matches.
- agent-device can refuse to tap a tab of the Members screen because it reads the tab as covered by another element while the tab is on screen. `selectTab` in the spec taps a point of the tab, which skips that check, and then expects the tab to be selected.
- `Manage` on the overview sheet is the only way into the profile from E2EHost. E2EHost shows no `OrganizationProfileView` of its own, so the profile always opens as the switcher's sheet.
- `No members found` is the empty state of a search, not of the list. The creator is always on the list.
- `Verified domains` shows only when the instance has domains on and the member can read or manage them. On the standard settings the creator always sees it.
- Back from Members and from Verified domains returns to the profile. The spec uses `device.back()`.
- The slug of an organization comes from its name, and Clerk refuses a slug that another organization in the instance holds with "That slug is taken. Please try another." Every test in a run shares the run id, and so does every attempt of a test that `--retries` runs again. So each test that creates an organization gives it its own prefix and a random suffix, such as `Profile <runId> <suffix>`, `Invite <runId> <suffix>`, and `Verify <runId> <suffix>` in `organizations`, and a retry does not create the slug its first attempt took.
- `Update profile` opens with the name filled in. `host.fill` types at the caret, so the rename test clears the field with `clear()` first. agent-device's `clear` leaves the text after the last hyphen of this field, so the organization the rename test creates has no hyphen in its name. A random suffix after a second space was also left behind, so that name joins its suffix to the run id.
