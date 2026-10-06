## Comments

Don't write comments unless they explain a constraint from a platform, library,
or spec that we can't change. If our own code needs explaining, change the code:
rename it, give it a type, extract a helper, or pin it with a test.

Keep license headers, doc comments on public API, and `// MARK:` markers.
Don't leave commented-out code.

## Verifying changes

Prove every change to ClerkKit, ClerkKitUI, or E2EHost on a real simulator before calling it done. The verification skill is `.claude/skills/verify-clerk-ios/` (Cursor also sees it as `.cursor/skills/verify-clerk-ios`). It needs a Mac with Xcode. Read its `SKILL.md`, then `features/README.md` for the feature you touched.

From the repo root, with Node 24.8 or newer, after `npm ci --prefix .claude/skills/verify-clerk-ios`:

1. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` checks the machine. Fix what it reports. `SKILL.md` under Launch lists what each machine needs once.
2. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios up` builds E2EHost, leases a simulator, and creates one Clerk application for this worktree. Every spec runs on that application's development instance. Creating it needs the team's Clerk Platform API key, and `doctor` says whether this machine has it.
3. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run <feature>` runs that feature's specs and keeps a video, screenshots, and state under `.claude/skills/verify-clerk-ios/.verify/runs/<run-id>/`.
4. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` releases the simulator and deletes the application with every test user in it. Evidence stays.

Type only test identities: `+clerk_test` emails, phones 555-0100 to 555-0199, and the code `424242`. Never enter real credentials.
