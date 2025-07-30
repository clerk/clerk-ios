# Quickstart

This is a companion project to the [iOS Quickstart guide](https://clerk.com/docs/quickstarts/ios). It demonstrates basic use of the [Clerk iOS Components](https://clerk.com/docs/references/ios/auth-view).

## Overview

This quickstart example shows how to:

- Configure the Clerk iOS SDK in a SwiftUI application
- Implement sign-in and sign-up flows using Clerk's pre-built components
- Handle authenticated and unauthenticated states
- Display the user profile and account management options

## Setup

### 1. Create a Clerk application

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk Dashboard
3. Copy your **Publishable Key** from the API Keys section

### 2. Configure the Example

1. Open `QuickstartApp.swift`
2. Replace `"YOUR_PUBLISHABLE_KEY"` with your actual Clerk publishable key:

```swift
clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
```

### 3. Run the App

1. Select the **Quickstart** scheme from the workspace navigator
2. Choose your target device/simulator
3. Build and run the project (⌘+R)