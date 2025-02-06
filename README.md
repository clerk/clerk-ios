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

<div align="center">
  <a href="https://swiftpackageindex.com/clerk/clerk-ios" style="text-decoration: none;">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fclerk%2Fclerk-ios%2Fbadge%3Ftype%3Dswift-versions" alt="Swift Versions">
  </a>
  <a href="https://swiftpackageindex.com/clerk/clerk-ios" style="text-decoration: none;">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fclerk%2Fclerk-ios%2Fbadge%3Ftype%3Dplatforms" alt="Platforms">
  </a>
  <a href="https://clerk.com/discord" style="text-decoration: none;">
    <img src="https://img.shields.io/discord/856971667393609759.svg?logo=discord" alt="Chat on Discord">
  </a>
  <a href="https://clerk.com/docs" style="text-decoration: none;">
    <img src="https://img.shields.io/badge/documentation-clerk-green.svg" alt="Documentation">
  </a>
  <a href="https://twitter.com/intent/follow?screen_name=ClerkDev" style="text-decoration: none;">
    <img src="https://img.shields.io/twitter/follow/ClerkDev?style=social" alt="Follow on Twitter">
  </a>
</div>


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

<!---

### CocoaPods

Clerk is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```bash
pod 'Clerk'
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

To integrate Clerk into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "KITGITHUBHANDLE/Clerk"
```

Run `carthage update --use-xcframeworks` to build the framework and drag the built `Clerk.xcframework` bundles from Carthage/Build into the "Frameworks and Libraries" section of your application’s Xcode project.

-->

### Swift Package Manager

To integrate using Apple's [Swift Package Manager](https://swift.org/package-manager/), navigate to your Xcode project, select `Package Dependencies` and click the `+` icon to search for `https://github.com/clerk/clerk-ios`.

Alternatively, add the following as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/clerk/clerk-ios", from: "0.1.0")
]
```

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
Prebuilt UI Components | ❌ 
Magic Links | ❌ 
Organizations | ❌ 
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
