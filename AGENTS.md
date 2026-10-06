## Verifying changes

Prove every change to ClerkKit, ClerkKitUI, or E2EHost on a real simulator before calling it done. This works on a Mac and on Linux: on a Mac the simulator is local, and on Linux the same commands lease one on a CI runner. The verification skill is `.claude/skills/verify-clerk-ios/` (Cursor also sees it as `.cursor/skills/verify-clerk-ios`). Read its `SKILL.md`, then `features/README.md` for the feature you touched.

From the repo root, with Node 24, after `npm ci --prefix .claude/skills/verify-clerk-ios`:

1. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` checks the machine. Fix what it reports.
2. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios up` builds E2EHost, leases a simulator, and creates one Clerk application for this worktree, whose development instance is the test instance every spec runs on. On Linux, commit and push first, because the remote session builds the pushed commit. Creating the application needs the team's Platform API key. A cloud environment attaches it as an API credential. On a Mac the CLI reads it from 1Password and asks you to approve, once you have set the key's 1Password reference from the team's private setup note. `doctor` says which it found, and the skill's `SKILL.md` under Test instances has the rest.
3. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run <feature>` puts the instance on the settings each spec file declares, runs that feature's specs, and keeps a video, screenshots, and state under `.claude/skills/verify-clerk-ios/.verify/runs/<run-id>/`.
4. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` releases the simulator and deletes the application with every test user in it. Evidence stays. On Linux run it as soon as you are done, because a remote session is billed by the minute.

Type only test identities: `+clerk_test` emails, phones 555-0100 to 555-0199, and the code `424242`. Never enter real credentials.
