## Comments

Don't write comments unless they explain a constraint from a platform, library,
or spec that we can't change. If our own code needs explaining, change the code:
rename it, give it a type, extract a helper, or pin it with a test.

Keep license headers, doc comments on public API, and `// MARK:` markers.
Don't leave commented-out code.

## Verifying changes

Prove every change to ClerkKit, ClerkKitUI, or E2EHost on a real simulator before calling it done. The verification skill is `.claude/skills/verify-clerk-ios/` (Cursor also sees it as `.cursor/skills/verify-clerk-ios`). On a Mac the simulator is local, and on Linux the same commands lease one on a CI runner. Read its `SKILL.md`, then `features/README.md` for the feature you touched.

`.claude/skills/verify-clerk-ios/bin/control-clerk-ios` has the verbs `doctor`, `up`, `run`, `down`, and `attach`, and `SKILL.md` has the steps.

Type only test identities: `+clerk_test` emails, phones 555-0100 to 555-0199, and the code `424242`. Never enter real credentials.
