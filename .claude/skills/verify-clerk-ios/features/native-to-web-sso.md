# Native to Web SSO

A signed-in user of the app opens one of the developer's web pages already signed in as the same user, with no second sign-in. The SDK creates a one-time session transfer for the active session and opens a Clerk page that redeems it and then redirects to the destination. `clerk.auth.loadInWebView(_:destination:)` loads it in the app's own `WKWebView`. E2EHost has a small screen of its own for this, `NativeToWebView`, which loads the instance's Account Portal and shows in a native label which user the page is signed in as.

## Sub-features

- `web-view` loads the Account Portal's `/user` page in a web view through `clerk.auth.loadInWebView`, and the page is signed in as the native user. `Done` returns to the home, still signed in as that user. Its second test shows that an instance with session transfers off refuses the transfer with `feature_not_enabled`.

## How to get to it (user POV)

- Launch the app signed in and tap `Native to Web SSO` on the home. The screen shows the web page's user ID or the transfer's error code at the top, a `Done` button, and the web view below.

## Driving it with verify

Preconditions:

- Clerk's `session_transfers` flag must be on for the instance. It's on globally. With it off, the first test cannot turn the feature on.
- Session transfers are off on the standard settings, so the first test calls `host.useSettings({ config: { 'session_transfers.enabled': true } })`. The leaf moves nothing in the public `/v1/environment` that the CLI reads, so the call names no `environment` and goes on after the CLI's 15-second wait.
- The Native API is on in the standard settings, which a session transfer needs.
- The landing page is the instance's own Account Portal, a Clerk web app on the same instance, so no web app needs hosting. The screen takes the scheme and host of `clerk.environment?.displayConfig.homeUrl`, `https://<slug>.accounts.dev/default-redirect` on a development instance, and sets the path to `/user`.

- **Signed in on the web.** Run `e2e-tests/bin/control-clerk-ios run native-to-web-sso --grep "same user"`. The test turns session transfers on, launches signed in with a ticket, reads the user ID from `e2e.auth.userId`, and taps `e2e.home.nativeToWeb`. It expects `e2e.nativeToWeb.webUserId` to read that ID within 30 seconds, with no `e2e.nativeToWeb.error`. Screenshot `web-view-signed-in`. It then taps `e2e.nativeToWeb.done` and expects the home with the same user.
- **Turned off.** Run `e2e-tests/bin/control-clerk-ios run native-to-web-sso --grep "turned off"`. The test keeps the standard settings, launches signed in, taps `e2e.home.nativeToWeb`, and expects `e2e.nativeToWeb.error` to read `feature_not_enabled`. Screenshot `web-view-feature-off`.
- **Proof.** `specs/features/native-to-web-sso/web-view.e2e.ts` passes. The video shows the Account Portal's profile page in the web view under the native user's ID.

## States a spec cannot reach

| State | Where the app decides | What it takes |
| --- | --- | --- |
| Opening the page in the user's browser | `Auth+SessionTransfer.swift`, `openInBrowser(destination:)` | The app hands the URL to the user's default browser, so the page is in another app that the harness does not read. E2EHost does not call it |
| A URL the app presents itself | `Auth+SessionTransfer.swift`, `prepareSessionTransfer(destination:presentation:)` | A screen of the app's own that loads `transfer.url`. `loadInWebView` calls it, so the web view test covers the request, but nothing tests a caller that presents the URL itself |
| A destination refused for its scheme or host | Clerk's checks of `destination` | A production instance, which requires `https` and a host on one of its domains. The harness creates development instances only, which allow any `http` or `https` URL |
| A refused sign-in that lands on the destination | `NativeToWebView.swift`, `sessionTransferFailureCode(in:)`, from `__clerk_status=session_transfer_failed` | A transfer that Clerk creates and then refuses to redeem. A token that Clerk does not recognize lands on the instance's home URL with `__clerk_error_code=invalid_token` instead of on the destination (`Auth+SessionTransfer.swift`, the doc comment of `prepareSessionTransfer`), and the screen checks every navigation, so it shows either. The spec's refusal comes before loading, from the create request |
| The web session ending at native sign-out | Clerk's revocation of a transferred web session when its native session ends | A web view that outlives the native session. The screen's data store is non-persistent, and `Done` drops the web view before a sign-out |

## Gotchas

- The web user ID comes from JavaScript on the page, `window.Clerk.user.id` once `window.Clerk.loaded` is true, not from the web view's accessibility tree. A change to how the Account Portal loads `window.Clerk` changes what the label shows.
- The page can finish loading more than once, with redirects after the transfer, so the screen reads the user again after each load and shows the result for the latest one.
- The web view uses `WKWebsiteDataStore.nonPersistent()`, so no web session survives between tests or launches. A signed-in label always comes from this screen's transfer.
- The screen never logs or stores the transfer URL. It works once, for about a minute, and signs the user in.
- The screen shows `Signed out on the web` when the page loaded but has no user, and `Loading the Account Portal` until the first answer. Neither has an identifier, so a failing wait shows them only in the screenshot.
- `e2e.nativeToWeb.error` shows codes of the screen's own as well as the transfer's (`NativeToWebView.swift`, `startTransfer` and `webView(_:didFinish:)`): `clerk_not_loaded` when the page never set `window.Clerk.loaded` within 30 seconds, `no_destination` when the environment has no `homeUrl`, and `load_failed` for an error that is not a `ClerkAPIError`.
