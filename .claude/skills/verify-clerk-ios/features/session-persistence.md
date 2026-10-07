# Session persistence

A signed-in user quits the app and opens it again. The app starts signed in, with the same session, and asks for nothing.

## Sub-features

- `relaunch` restores the session from the keychain after the app process is killed and started again.

## How to get to it (user POV)

- Sign in, quit the app, and open it again.

## Driving it with verify

Preconditions:

- The spec declares no settings, so it runs on the standard settings.
- The spec seeds a `+clerk_test` user and signs in with a ticket on the home.

- **Relaunch.** Run `e2e-tests/bin/control-clerk-ios run session-persistence`. The spec reads the session ID on the home (`e2e.auth.sessionId`), then launches again with `keepStorage: true` and no `signedInAs`. That launch kills the process and starts it with the same storage scope and no sign-in ticket. The spec waits for the home to show the same user, and expects the same session ID. Screenshot `relaunched`.
- **Proof.** `specs/golden/session-persistence/relaunch.e2e.ts` passes. The video shows the home with the user, the app closing, and the home with the same user and session ID.

## Gotchas

- Only the second launch tests persistence. It carries no ticket, so the only way the home can show a user is the session that ClerkKit stored in the keychain.
- A launch with `keepStorage` and no `signedInAs` needs `landsOn`, because the fixture cannot know what stored state should show. The spec names `host.app.signedIn`.
- E2EHost passes the storage scope to `Clerk.Options` as the keychain service `verify.<scope>`. An app that changes its keychain service between launches starts signed out.
