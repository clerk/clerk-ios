# Organization profile

A member of the active organization opens its profile from OrganizationSwitcher, renames the organization, sees its members, invites people, reaches its verified domains, and can leave or delete the organization. Which rows, tabs, and buttons show depends on the member's permissions in the organization and on the instance's settings.

## Sub-features

- `profile` shows the creator every row of the profile: `Update profile` under the organization's name, `Members`, `Verified domains`, `Leave organization`, and `Delete organization`. `Members` shows the creator, marked `You`, on the `Members` tab, `No invitations sent` on `Invitations`, `No membership requests` on `Requests`, and `No members found` for a search that matches no one. `Verified domains` shows the `Add domain` row and no `No verified domains`. `Leave organization` asks the user to type the organization's name. `Delete organization` deletes it after the user types the name, and the switcher reads `Personal account` again.
- `invitation-sent` sends an invitation to a new `+clerk_test` address from `Invite` on the Members screen, and the address shows on the `Invitations` tab.
- `rename` changes the organization's name on `Update profile`, and the profile shows the new name.
- `org-domains-empty` shows `No verified domains` and no `Add domain` to a member whose role can read domains but not manage them.
- `org-requests` shows a request to join on the `Requests` tab, from a user who signed up with an address at the organization's verified domain.
- `embedded-profile` keeps OrganizationProfileView mounted in a tab, with Members and then Verified domains open, while the user makes another organization active from the `Accounts` tab. Each screen then shows only the new active organization's rows.

## How to get to it (user POV)

- With an organization active, the OrganizationSwitcher on the home shows the organization's name. Tap it. A sheet titled `Organization` shows the name, the user's role, `Manage`, and `Switch account`. Tap `Manage`. The profile opens in a sheet titled `Organization`.
- From the profile, tap `Update profile`, `Members`, `Verified domains`, `Leave organization`, or `Delete organization`. On the Members screen, the three tabs are at the top and `Invite` is at the top right.

## Driving it with verify

Preconditions:

- The first three tests seed a `+clerk_test` user on the standard settings, sign in with a ticket, and create an organization from the switcher with `openNewOrganizationProfile` in the spec file, which then opens `Manage`. The last two seed the organization with `host.seedOrganization`, and the seeded organization is active when a member signs in with a ticket. The user who creates an organization holds the `org:admin` role (`creator_role` in `src/core/instances/base.json`), which has every permission. The standard settings turn on domains, allow three members, and let an admin delete the organization.

- **Profile.** Run `e2e-tests/bin/control-clerk-ios run organization-profile`. The first test expects the five rows and takes screenshot `org-profile`. It opens `Members`, expects `You`, the user's email, and `Invite`, and takes screenshot `org-members`. It selects `Invitations` and expects `No invitations sent` (`org-invitations-empty`), selects `Requests` and expects `No membership requests` (`org-requests-empty`), selects `Members` again, types a name that matches no one into the search field, and expects `No members found` (`org-members-no-match`). It goes back, opens `Verified domains`, expects `Add domain` and no `No verified domains` (`org-domains`), and goes back. It opens `Update profile` and expects `clerk.organization.profileForm.name` (`org-update-profile`), then cancels. It opens `Leave organization`, expects `Type "<name>" below to continue.` (`org-leave-confirmation`), and cancels. It opens `Delete organization`, types the name, and confirms (`org-delete-confirmation`). The home then shows the same user and `Personal account`, with no organization name (`org-deleted`).
- **Invitation.** The second test opens `Members`, taps `Invite`, fills `Enter email addresses` with `host.newEmail()`, taps `Send invitations`, selects `Invitations`, and expects the address. Screenshot `invitation-sent`.
- **Rename.** The third test taps `Update profile`, clears `clerk.organization.profileForm.name`, fills it with another `host.newOrganizationName()`, and taps `clerk.organization.profileForm.submit`. It expects the form gone and the new name on the profile. Screenshot `org-renamed`.
- **Domains reader.** The fourth test seeds an admin and a reader, and an organization with the reader as `org:e2e_domains_reader`. It signs the reader in, taps the organization's name, expects the role `Domains reader`, taps `Manage`, then `Verified domains`, and expects `No verified domains` and no `Add domain`. Screenshot `org-domains-empty`.
- **Request to join.** The fifth test seeds an admin and an organization with `suggestDomain: true`. It signs up a new user through the full-screen AuthView with `host.newEmail({ domain: org.domain })`, the test code, and the run password. That user taps `Personal account`, taps `Request to join` on the suggestion, and expects `Pending approval`. Then it signs the admin in, opens `Manage`, `Members`, and the `Requests` tab, and expects the requester's email and no `No membership requests`. Screenshot `org-requests`.
- **Embedded profile.** Run `e2e-tests/bin/control-clerk-ios run organization-profile/embedded-profile`. The spec seeds an admin with two organizations, one of them with a second member and a verified domain. It opens `Organization tabs`, makes the first organization active from `Accounts`, opens `Members` on the `Organization` tab, and expects the admin and not the member (`members-first-org`). It makes the second organization active and expects the member on the same Members screen (`members-after-switch`). It goes back, opens `Verified domains`, and expects the domain (`domains-team-org`). It makes the first organization active again and expects `Add domain` and not the domain (`domains-after-switch`). [Organizations](./organizations.md) describes the tabs.
- **Proof.** `specs/features/organization-profile/organization-profile.e2e.ts` passes, and the screenshots show each screen with the organization's name or the creator's email. `down` deletes the application, and every organization and invitation goes with it.

## States a spec cannot reach

`host.seedOrganization` adds other members and the `org:e2e_domains_reader` role, so the tests above reach `No verified domains` and a non-empty `Requests` tab. These states are still out of reach:

| State | Where the app decides | Why |
| --- | --- | --- |
| The Members screen with no tab | `OrganizationMembersView.swift`, `availableTabs` | Unreachable by design. The screen has no tab when the member can neither read nor manage memberships, and the same check hides the `Members` row in `OrganizationProfileView.swift`, so the profile never opens the screen in that state. Only a role revoked while the screen is open shows it, for a moment. |
| The role-set warning on Members and on Invite | `OrganizationMembersTabView.swift`, `OrganizationInviteMembersView.swift` | An instance that is moving its organizations to another role set. Specs cannot start that move. |

Seeding also reaches these states, and no spec drives them yet: the Members screen with one tab and no `Invite`, and no `Update profile` or `Delete organization`, for the `org:e2e_domains_reader` member; another member's row with `Change role` and `Remove member`, for an admin with a second member.

These states need other settings, which a spec file can declare, and no spec drives them yet. With `domains_enabled` off, the profile has no `Verified domains` row and Members has no `Requests` tab. An organization created while `admin_delete_enabled` is off has no `Delete organization` row. `Invite` is off once the members and the pending invitations reach `max_allowed_memberships`, which is three on the standard settings, so two invitations turn it off.

A change to the role-set warning is shown on a build with a local change that is not part of the pull request, and the pull request says so. Name the change and the screens it affects, and keep the spec in `specs/explored/`.

## Gotchas

- No row, tab, or button of the profile has an identifier except the name, slug, and submit of `Update profile`, which share the `clerk.organization.profileForm.*` identifiers with the create form. The spec finds rows and buttons with `getByRole('button', { name })` and tabs with `getByRole('tab', { name })`. `Members` is a row, a tab, and the title of the Members screen.
- `screen` prints each tab of the Members screen as a `button`, but a locator matches it only as a `tab`. The tree on a failure page shows the role that a locator matches.
- agent-device refuses a tap on the Members screen with "covered by another visible element" while nothing covers the control. The screen tree of that sheet ends with a node of type `Toolbar` whose frame is the whole sheet, and agent-device takes a toolbar for an overlay unless a sibling has the same frame. On the profile and on Invite new members a scroll view has that frame, so their controls are not refused. On the Members screen the navigation bar, the tabs, the search field, and the list are separate nodes, so agent-device marks every control under the toolbar's frame as covered: the tabs, the search field, and `Invite`. A tap at a point of the control reaches it, because the toolbar takes no touches. So the spec taps these three through `atCenter`, which taps the middle of the control's box and skips agent-device's check. Each such tap is followed by an assertion on what the tap opens or selects, so a control that is really covered still fails the test.
- `Manage` on the overview sheet is the only way into the profile from E2EHost. E2EHost shows no `OrganizationProfileView` of its own, so the profile always opens as the switcher's sheet.
- `No members found` is the empty state of a search, not of the list. The creator is always on the list.
- `Verified domains` shows only when the instance has domains on and the member can read or manage them. On the standard settings the creator always sees it.
- Back from Members and from Verified domains returns to the profile. The spec taps the navigation bar's `Back` button with `host.back()`.
- The slug of an organization comes from its name, and Clerk refuses a slug that another organization in the instance holds with "That slug is taken. Please try another." Every test in a run shares the run id, and so does every attempt of a test that `--retries` runs again. So each test that creates an organization names it with `host.newOrganizationName()`, a word that no other test of the run and no retry gets, and the run tag, such as `Harbor 7c1e`. A retry does not create the slug its first attempt took.
- For less than a second after `Update profile` closes, the screen tree also holds the home behind the sheet, with the organization's name on the switcher. A locator for the new name then matches the switcher too and fails as ambiguous. The rename test waits until exactly one node shows the new name, which is the profile's.
- `Update profile` opens with the name filled in. `host.fill` types at the caret, so the rename test clears the field with `clear()` first. agent-device's `clear` leaves the text after the last hyphen of this field, and the text after a second space, so an organization name has no hyphen and one space.
