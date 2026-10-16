## Strings

User-facing text is in two catalogs. `Sources/ClerkKitUI/Resources/Localizable.xcstrings` holds the text of the prebuilt views, and `Sources/ClerkKit/Resources/Localizable.xcstrings` holds the error text of the core SDK. In both, the English text is the key, and each key holds a translation for every language the SDK ships.

When you change English text, rename its key in the catalog that holds it and update the translation in every language to say what the new text says. Old translations kept under a new key still say what the old text said.

A key marked `"shouldTranslate" : false` holds text that is the same in every language. It has no translations, whether you add it or change it.

## Comments

Don't write comments unless they explain a constraint from a platform, library,
or spec that we can't change. If our own code needs explaining, change the code:
rename it, give it a type, extract a helper, or pin it with a test.

Keep license headers, doc comments on public API, and `// MARK:` markers.
Don't leave commented-out code.

## Verifying changes

Prove every change to ClerkKit, ClerkKitUI, or E2EHost on a simulator before calling it done, and put the screenshots or video on the pull request. How you prove it is up to you. The verification skill in this repository is one way, and it also works on a machine with no device. An app of your own that exercises the change is just as good. If you could not run it on a device at all, say so in the pull request.

Show a before and an after of every screen the change touches, and of every state of those screens, including a state that should look the same after the change. When a test user cannot reach a state with the standard instance settings and default roles, and no settings or test data can, force it with a small local patch on both builds. Never commit the patch, and say in the pull request what it changed and why. When you review a pull request that changes SDK or UI code, check that its evidence covers every screen and state the diff touches.

The verification skill is `.claude/skills/verify-clerk-ios/` (Cursor sees it as `.cursor/skills/verify-clerk-ios` and Codex as `.agents/skills/verify-clerk-ios`). On a Mac the simulator is local, and on a machine that is not a Mac the same commands lease one on a CI runner. The tests and the CLI that runs them are in `e2e-tests/`. Read the skill's `SKILL.md`, then the page for the feature you touched, which `.claude/skills/verify-clerk-ios/features/README.md` lists. The skill needs a Clerk Platform API key, which Clerk team members have.

`e2e-tests/bin/control-clerk-ios` has the verbs `doctor`, `up`, `run`, `screen`, `attach`, and `down`, and `SKILL.md` has the steps. Run `make check` before you push, as `CONTRIBUTING.md` says.

Type only test identities: `+clerk_test` emails, phones 555-0100 to 555-0199, and the code `424242`. Never enter real credentials.
