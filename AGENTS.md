## Comments

Don't write comments unless they explain a constraint from a platform, library,
or spec that we can't change. If our own code needs explaining, change the code:
rename it, give it a type, extract a helper, or pin it with a test.

Keep license headers, doc comments on public API, and `// MARK:` markers.
Don't leave commented-out code.

## Verifying changes

Prove every change to ClerkKit, ClerkKitUI, or E2EHost on a real simulator before calling it done. The verification skill is `.claude/skills/verify-clerk-ios/` (Cursor also sees it as `.cursor/skills/verify-clerk-ios`). On a Mac the simulator is local, and on Linux the same commands lease one on a CI runner. The tests and the CLI that runs them are in `e2e-tests/`. Read the skill's `SKILL.md`, then the page for the feature you touched, which `.claude/skills/verify-clerk-ios/features/README.md` lists. The skill needs a Clerk Platform API key, which Clerk team members have. Without one, say in the pull request that the change was not run on a device.

`e2e-tests/bin/control-clerk-ios` has the verbs `doctor`, `up`, `run`, `screen`, `attach`, and `down`, and `SKILL.md` has the steps. Run `make check` before you push, as `CONTRIBUTING.md` says.

Type only test identities: `+clerk_test` emails, phones 555-0100 to 555-0199, and the code `424242`. Never enter real credentials.
