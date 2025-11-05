# AppleWatchExample

This example demonstrates how to share authentication state between an iOS app and its companion Apple Watch app using Clerk's shared keychain configuration.

## Overview

This example consists of two apps:

- **iOS App** - Handles authentication (sign-in/sign-up) using Clerk's UI components
- **watchOS App** - Displays shared authentication state from the iOS app

This example shows how to:

- Configure Clerk with a shared access group to enable keychain sharing between iOS and watchOS apps
- Handle authentication on iOS using Clerk's pre-built UI components
- Access shared authentication state on watchOS from the iOS app
- Display user information from the shared auth state on Apple Watch

## Architecture

When a user signs in on the iOS app, their authentication state is stored in a shared keychain using a Keychain Access Group. The watchOS app can then access this shared state without requiring separate authentication.

## Setup

### 1. Create a Clerk application

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk Dashboard
3. Copy your **Publishable Key** from the API Keys section

### 2. Configure Keychain Sharing

Both your iOS app and watchOS app must be configured with the same Keychain Access Group:

1. In Xcode, select your iOS app target (AppleWatchExample)
2. Go to **Signing & Capabilities**
3. Add the **Keychain Sharing** capability
4. Add the access group: `group.com.clerk.AppleWatchExample`
5. Repeat for your watchOS app target (AppleWatchExample Watch App)

### 3. Configure Clerk in Both Apps

Both apps must use the same access group when configuring Clerk. The configuration is already set up in both apps:

**iOS App (`AppleWatchExampleApp.swift`):**
```swift
let keychainConfig = KeychainConfig(
  accessGroup: "group.com.clerk.AppleWatchExample"
)
let options = Clerk.ClerkOptions(keychainConfig: keychainConfig)
Clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY", options: options)
```

**watchOS App (`AppleWatchExampleApp.swift` in Watch App folder):**
```swift
let keychainConfig = KeychainConfig(
  accessGroup: "group.com.clerk.AppleWatchExample"
)
let options = Clerk.ClerkOptions(keychainConfig: keychainConfig)
Clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY", options: options)
```

### 4. Update the Example

1. Open `AppleWatchExample/AppleWatchExampleApp.swift`
2. Replace `"YOUR_PUBLISHABLE_KEY"` with your actual Clerk publishable key
3. Open `AppleWatchExample Watch App/AppleWatchExampleApp.swift`
4. Replace `"YOUR_PUBLISHABLE_KEY"` with the same publishable key
5. Ensure the access group matches your Keychain Access Group identifier in both files

### 5. Run the Apps

1. Select the **AppleWatchExample** scheme from the workspace navigator
2. Build and run the iOS app first and sign in
3. Then run the watchOS app - it will automatically access the shared auth state

## How It Works

1. When a user signs in on the iOS app, Clerk stores the session token and user data in the shared keychain using the Keychain Access Group
2. The watchOS app configures Clerk with the same access group, allowing it to read from the same keychain
3. When the watchOS app calls `Clerk.shared.load()`, it retrieves the shared authentication state
4. The watchOS app can then access `Clerk.shared.user` to display user information without requiring separate authentication

