# Airbnb example on the generated core

The app retains one `Clerk` owner and its native browser, passkey, and Apple
presenters. The generated future-style resources drive the existing custom forms.
Every completed authentication attempt explicitly calls `finalize()`; remaining
requirements and session tasks open `AuthView` against the same owner. The profile
requires an active session with no pending task.

The sign-up-first email/phone flow switches to sign-in only for
`form_identifier_exists`. Network, capability, and other verification failures stay
visible. Social flows use the core's transferable SSO result and finalize its actual
sign-in or sign-up resource. Native Apple identity uses `oauth_token_apple`.

Configure the existing local development key and callback
`com.clerk.AirbnbClone://oauth/callback`. Build the `AirbnbClone` scheme from
`Clerk.xcworkspace`, which supplies the local ClerkKit and ClerkKitUI products.
Simulator builds verify the generated Swift API; real sign-in, OS prompts, and
upgrades remain device-validation requirements.
