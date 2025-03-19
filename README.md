<p align="center">
  <a href="https://clerk.com?utm_source=github&utm_medium=clerk_ios" target="_blank" rel="noopener noreferrer">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://images.clerk.com/static/logo-dark-mode-400x400.png">
      <img src="https://images.clerk.com/static/logo-light-mode-400x400.png" height="260">
    </picture>
  </a>
  <br />
</p>
<h1 align="center">
  Official Clerk iOS SDK (Beta)
</h1>
<p align="center">
  <strong>
    Clerk helps developers build user management. We provide streamlined user experiences for your users to sign up, sign in, and manage their profile.
  </strong>
</p>

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fclerk%2Fclerk-ios%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/clerk/clerk-ios)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fclerk%2Fclerk-ios%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/clerk/clerk-ios)
[![chat on Discord](https://img.shields.io/discord/856971667393609759.svg?logo=discord)](https://clerk.com/discord)
[![documentation](https://img.shields.io/badge/documentation-clerk-green.svg)](https://clerk.com/docs)
[![twitter](https://img.shields.io/twitter/follow/ClerkDev?style=social)](https://twitter.com/intent/follow?screen_name=ClerkDev)


<p align="center">
  ℹ️ While minor breaking changes (method names, parameter names, etc.) can be expected until version 1.0.0, the iOS SDK is considered stable.
</p>

---

**Clerk is Hiring!**

Would you like to work on Open Source software and help maintain this repository? [Apply today!](https://jobs.ashbyhq.com/clerk)

---

## 🚀 Get Started with Clerk

1. [Sign up for an account](https://dashboard.clerk.com/sign-up?utm_source=github&utm_medium=clerk_ios_repo_readme)
1. Create an application in your Clerk dashboard
1. Spin up a new codebase with the [quickstart guide](https://clerk.com/docs/quickstarts/ios?utm_source=github&utm_medium=clerk_ios_repo_readme)

## 🧑‍💻 Installation

### Swift Package Manager

To integrate using Apple's [Swift Package Manager](https://swift.org/package-manager/), navigate to your Xcode project, select `Package Dependencies` and click the `+` icon to search for `https://github.com/clerk/clerk-ios`.

Alternatively, add the following as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/clerk/clerk-ios", from: "0.1.0")
]
```

## 🛠️ Usage

First, configure Clerk in your app's entry point:

```swift
import SwiftUI
import Clerk

@main
struct ClerkQuickstartApp: App {
  @State private var clerk = Clerk.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(clerk)
        .task {
          clerk.configure(publishableKey: "your_publishable_key")
          try? await clerk.load()
        }
    }
  }
}
```

Now in your views, you can conditionally render content based on the user's session:

```swift
import SwiftUI
import Clerk

struct ContentView: View {
  @Environment(Clerk.self) private var clerk

  var body: some View {
    VStack {
      if let user = clerk.user {
        Text("Hello, \(user.id)")
      } else {
        Text("You are signed out")
      }
    }
  }
}
```

### Authentication

#### Sign Up with Email and Perform Verification
```swift
// Create a sign up
var signUp = try await SignUp.create(
  strategy: .standard(emailAddress: "user@example.com", password: "••••••••••••")
)

// Check if the SignUp needs the email address verified and send an OTP code via email.
if signUp.unverifiedFields.contains("email_address") {
  signUp = try await signUp.prepareVerification(strategy: .emailCode)
}

// After collecting the OTP code from the user, attempt verification
signUp = try await signUp.attemptVerification(strategy: .emailCode(code: "12345"))
```

#### Passwordless Sign In
```swift
// Create the sign in
var signIn = try await SignIn.create(
  strategy: .identifier("user@example.com", strategy: "email_code")
)
      
// After collecting the OTP code from the user, attempt verification
signIn = try await signIn.attemptFirstFactor(for: .emailCode(code: "12345"))
```

#### Sign In with OAuth (e.g. Google, Github, etc.)
```swift
try await SignIn.authenticateWithRedirect(strategy: .oauth(provider: .google))
```

#### Native Sign in with Apple
```swift
// Use the Clerk SignInWithAppleHelper class to get your Apple credential
let credential = try await SignInWithAppleHelper.getAppleIdCredential()

// Convert the identityToken data to String format
guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else { return }

// Authenticate with Clerk
try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
```

#### Forgot Password
```swift
// Create a sign in and send an OTP code to verify the user owns the email.
var signIn = try await SignIn.create(
  strategy: .identifier("user@example.com", strategy: "reset_password_email_code")
)

// After collecting the OTP code from the user, attempt verification.
signIn = try await signIn.attemptFirstFactor(for: .resetPasswordEmailCode(code: "12345"))

// Set a new password to complete the process.
signIn = try await signIn.resetPassword(.init(password: "••••••••••••", signOutOfOtherSessions: true))
```

#### Sign Out
```swift
try await clerk.signOut()
```

### User Management

#### Update User Profile
```swift
try await user.update(firstName: "John", lastName: "Appleseed")
```

#### Update User Profile Image
```swift 
let imageData = try await photosPickerItem.loadTransferable(type: Data.self)
try await user.setProfileImage(imageData: imageData)
```

#### Link an External Account
```swift
let externalAccount = try await user.createExternalAccount(provider: .github)
try await externalAccount.reauthorize()
```

For a full set of features and functionality, please see our docs!
## 🎓 Docs

- [iOS SDK Reference](https://swiftpackageindex.com/clerk/clerk-ios/main/documentation/clerk)
- [Clerk iOS](https://clerk.com/docs/references/ios/overview)
- [Custom Flows](https://clerk.com/docs/custom-flows/overview)

## ✅ Supported Features

| Feature | iOS Support
--- | :---:
Email/Phone/Username Authentication | ✅
Email Code Verification | ✅
SMS Code Verification | ✅
Multi-Factor Authentication (TOTP / SMS) | ✅
Sign in / Sign up with OAuth | ✅
Native Sign in with Apple | ✅
Session Management | ✅ 
Multi-Session Applications | ✅ 
Forgot Password | ✅
User Management | ✅ 
Passkeys | ✅
Enterprise SSO (SAML) | ✅ 
Device Attestation | ✅
Organizations | ✅
Prebuilt UI Components | ❌ 
Magic Links | ❌ 
Sign Up via Invitation | ❌
Web3 Wallet | ❌

## 🚢 Release Notes

Curious what we shipped recently? Check out our [changelog](https://clerk.com/changelog)!

<!---
## 🤝 How to Contribute

We're open to all community contributions! If you'd like to contribute in any way, please read [our contribution guidelines](https://github.com/clerk/javascript/blob/main/docs/CONTRIBUTING.md). We'd love to have you as part of the Clerk community!
-->

## 📝 License

This project is licensed under the **MIT license**.

See [LICENSE](https://github.com/clerk/javascript/blob/main/LICENSE) for more information.
