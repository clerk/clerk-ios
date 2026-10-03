## Verifying changes

Prove every change to ClerkKit, ClerkKitUI, or E2EHost on a real simulator before calling it done. The verification skill is `.cursor/skills/verify-clerk-ios/`. Read its `SKILL.md`, then `features/README.md` for the feature you touched.

From `.cursor/skills/verify-clerk-ios/`, after `npm ci`:

1. `bin/verify doctor` checks the machine. Fix what it reports.
2. `bin/verify up` builds E2EHost and leases a lane simulator.
3. `bin/verify run <feature>` runs that feature's specs and keeps a video, screenshots, and state under `.verify/runs/<run-id>/`.
4. `bin/verify down` releases the simulator and deletes the test users. Evidence stays.

Type only test identities: `+clerk_test` emails, phones 555-0100 to 555-0199, and the code `424242`. Never enter real credentials.
