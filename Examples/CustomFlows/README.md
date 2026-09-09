# Custom authentication flows

This example uses the new generated native API. `CustomFlowsConnection` retains one `Clerk` and the platform authentication presenter. Copy the local secrets template and supply a development publishable key; configure the selected authentication methods and callback route for that instance.

Email, phone, password, MFA, legal acceptance and SSO examples call the generated resource methods. Successful verification can leave additional requirements. They explicitly call `finalize()` only when their attempt is complete; a pending session is shown in the native task UI. Requirements outside a small example's own form continue in `AuthView` using the same owner. Errors are shown in the application rather than dumping session objects.

The registered callback is `com.clerk.CustomFlows://oauth/callback`. Incoming callbacks are retained until startup completes and forwarded to the generated callback handler. Browser OAuth, enterprise SSO, passkeys and Apple sign-in use the app's `AppleAuthentication` presenter. The custom SSO examples use the core's transfer-aware operation so a new user can continue sign-up without native domain orchestration.

The local Simulator build verifies source integration. Real instance configuration, associated-domain requirements, OS prompts and signed-in upgrade continuity still need device verification; fixture previews do not establish those behaviors.
