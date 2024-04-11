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
  Official Clerk iOS SDK (Alpha)
</h1>
<h3 align="center">
  <strong>
    ⚠️ The Clerk iOS SDK is in alpha and not recommended for use in production. ⚠️
  </strong>
</h3>
<p align="center">
  Breaking changes should be expected until the first stable release (1.0.0)
</p>
<p align="center">
  <strong>
    Clerk helps developers build user management. We provide streamlined user experiences for your users to sign up, sign in, and manage their profile.
  </strong>
</p>

Visit [clerk.com](https://clerk.com) to signup for an account.

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
1. Spin up a new codebase with one of the [quickstart guides](https://clerk.com/docs/quickstarts/overview?utm_source=github&utm_medium=clerk_ios_repo_readme)

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

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate Clerk into your project manually. Simply drag the `Sources` Folder into your Xcode project.

## 🎓 Learning Clerk

Clerk's full documentation is available at [clerk.com/docs](https://clerk.com/docs?utm_source=github&utm_medium=clerk_ios_repo_readme).

- **We recommend starting with the [Quickstart guides](https://clerk.com/docs/quickstarts/overview).** It'll enable you to quickly add Clerk to your application.
- **To learn more about Clerk's components and features, checkout the rest of the [Clerk documentation](https://clerk.com/docs?utm_source=github&utm_medium=clerk_ios_repo_readme).** You'll be able to e.g. browse the [component reference](https://clerk.com/docs/components/overview?utm_source=github&utm_medium=clerk_ios_repo_readme) page.

## 🚢 Release Notes

Curious what we shipped recently? Check out our [changelog](https://clerk.com/changelog)!

<!---
## 🤝 How to Contribute

We're open to all community contributions! If you'd like to contribute in any way, please read [our contribution guidelines](https://github.com/clerk/javascript/blob/main/docs/CONTRIBUTING.md). We'd love to have you as part of the Clerk community!
-->

## 📝 License

This project is licensed under the **MIT license**.

See [LICENSE](https://github.com/clerk/javascript/blob/main/LICENSE) for more information.
