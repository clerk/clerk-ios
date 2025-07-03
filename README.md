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
  Official Clerk iOS SDK
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

---

**Clerk is Hiring!**

Would you like to work on Open Source software and help maintain this repository? [Apply today!](https://jobs.ashbyhq.com/clerk)

---

## 🚀 Get Started with Clerk

1. [Sign up for an account](https://dashboard.clerk.com/sign-up?utm_source=github&utm_medium=clerk_ios_repo_readme)
1. Create an application in your Clerk dashboard
1. Spin up a new codebase with the [quickstart guide](https://clerk.com/docs/quickstarts/ios?utm_source=github&utm_medium=clerk_ios_repo_readme)

## 🧑‍💻 Installation

### Requirements
- iOS 17+ / Mac Catalyst 17+ / macOS 14+ / tvOS 17+ / watchOS 10+ / visionOS 1+
- Xcode 16+
- Swift 5.10+

### Swift Package Manager

To integrate using Apple's [Swift Package Manager](https://swift.org/package-manager/), navigate to your Xcode project, select `Package Dependencies` and click the `+` icon to search for `https://github.com/clerk/clerk-ios`.

Alternatively, add the following as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/clerk/clerk-ios", from: "0.1.0")
]
```

## ⚙️ Configuration

### Add your Native Application

Add your iOS application to the <a href="https://dashboard.clerk.com/last-active?path=/native-applications" target="_blank">**Native Applications**</a> page in the Clerk dashboard. You will need your iOS app's **App ID Prefix** and **Bundle ID**.

### Add Associated Domain Capability

To enable seamless authentication flows, you need to add an associated domain capability to your iOS app. This allows your app to work with Clerk's authentication services.

1. In Xcode, select your project in the Project Navigator.
2. Select your app target.
3. Go to the **Signing & Capabilities** tab.
4. Click the **+ Capability** button.
5. Search for and add **Associated Domains**.
6. Under **Associated Domains**, add a new entry with the value: `webcredentials:{FRONTEND_API_URL}`

> Replace `{FRONTEND_API_URL}` with your Frontend API URL. You can find your Frontend API URL in the <a href="https://dashboard.clerk.com/last-active?path=native-applications" target="_blank">**Native Applications**</a> page in the Clerk Dashboard.

### Allowlist for Mobile SSO Redirect

1. In the Clerk Dashboard, navigate to the <a href="https://dashboard.clerk.com/last-active?path=/native-applications" target="_blank">**Native Applications**</a> page.
2. In the **Allowlist for mobile SSO redirect** section, add your app's callback URL in the format: `{BUNDLE_ID}://callback`

> Replace `{BUNDLE_ID}` with your app's actual Bundle Identifier (e.g., `com.yourcompany.yourapp://callback`).

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
        .environment(\.clerk, clerk)
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
  @Environment(\.clerk) private var clerk

  var body: some View {
    VStack {
      if let user = clerk.user {
        Text("Hello, \(user.firstName ?? "User")")
      } else {
        Text("You are signed out")
      }
    }
  }
}
```

### 🧩 UI Components

Clerk provides prebuilt SwiftUI components that handle authentication flows and user management.

| AuthView |
|----------|
| <img src="https://github.com/user-attachments/assets/eeb712a3-8a84-4247-9aa9-ef53128c6121" width="200" alt="AuthView demo"> <img src="https://github.com/user-attachments/assets/7d572c63-1dfa-4b93-a8e0-cf9645d43796" width="200" alt="AuthView demo 2"> <img src="https://github.com/user-attachments/assets/252e4a66-8e53-40b3-99c1-16e6ac40fb93" width="200" alt="AuthView demo 3"> |

| UserProfileView |
|-----------------|
| <img src="https://github.com/user-attachments/assets/a59c3b9e-d726-4939-8553-087178a28413" width="200" alt="UserProfileView demo"> <img src="https://github.com/user-attachments/assets/9b1e56d1-0f67-4db4-8c4f-bb49dacb27e2" width="200" alt="UserProfileView demo 2"> <img src="https://github.com/user-attachments/assets/56f4487c-07ad-4420-99a0-0f4aebd3523f" width="200" alt="UserProfileView demo 3"> |

#### AuthView - Complete Authentication Experience

```swift
struct HomeView: View {
  @Environment(\.clerk) private var clerk
  @State private var authIsPresented = false

  var body: some View {
    ZStack {
      if clerk.user != nil {
        UserButton()
          .frame(width: 36, height: 36)
      } else {
        Button("Sign in") {
          authIsPresented = true
        }
      }
    }
    .sheet(isPresented: $authIsPresented) {
      AuthView()
    }
  }
}
```

#### UserButton - Profile Access Button
```swift
// In a navigation toolbar
.toolbar {
  ToolbarItem(placement: .navigationBarTrailing) {
    if clerk.user != nil {
      UserButton()
        .frame(width: 36, height: 36)
    }
  }
}
```

#### UserProfileView - Full Profile Management
```swift
struct ProfileView: View {
  @Environment(\.clerk) private var clerk

  var body: some View {
    if clerk.user != nil {
      UserProfileView()
    } else {
      AuthView(isDismissable: false)
    }
  }
}
```

#### 🎨 Custom Theming

Clerk UI components can be customized with a custom theme to match your app's design:

```swift
import SwiftUI
import Clerk

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.clerkTheme, customTheme)
    }
  }
}

let customTheme = ClerkTheme(
  colors: .init(primary: .blue),
  fonts: .init(fontFamily: "Montserrat"),
  design: .init(borderRadius: 10)
)
```

### 🔐 Custom Authentication Flows

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
  strategy: .identifier("user@example.com", strategy: .emailCode())
)
      
// After collecting the OTP code from the user, attempt verification
signIn = try await signIn.attemptFirstFactor(strategy: .emailCode(code: "12345"))
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
  strategy: .identifier("user@example.com", strategy: .resetPasswordEmailCode())
)

// After collecting the OTP code from the user, attempt verification.
signIn = try await signIn.attemptFirstFactor(strategy: .resetPasswordEmailCode(code: "12345"))

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
try await user.update(.init(firstName: "John", lastName: "Appleseed"))
```

#### Update User Profile Image
```swift 
let imageData = try await photosPickerItem.loadTransferable(type: Data.self)
try await user.setProfileImage(imageData: imageData)
```

#### Add Phone Number
```swift
// Create a new phone number on the user's account
var newPhoneNumber = try await user.createPhoneNumber("5555550100")

// Send an OTP verification code via SMS to the phone number
newPhoneNumber = try await newPhoneNumber.prepareVerification()

// After collecting the OTP code from the user, attempt verification.
newPhoneNumber = try await newPhoneNumber.attemptVerification(code: "12345")
```

#### Link an External Account
```swift
let externalAccount = try await user.createExternalAccount(provider: .github)
try await externalAccount.reauthorize()
```

### Session Tokens
```swift
if let token = try await Clerk.shared.session?.getToken()?.jwt {
  headers["Authorization"] = "Bearer \(token)"
}
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
Prebuilt UI Components | ✅ 
Magic Links | ❌ 
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
