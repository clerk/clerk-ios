# WatchExampleApp

This example demonstrates how to sync authentication state bidirectionally between an iOS app and its companion Apple Watch app using Clerk's Watch Connectivity integration.

## Overview

This example consists of two apps:

- **iOS App** - Handles authentication (sign-in/sign-up) and automatically syncs authentication state to the watch app
- **watchOS App** - Receives synced authentication state and can also sync changes back to the iOS app

The apps use two-way sync to keep authentication state synchronized:
- When you sign in on the iOS app, your authentication state automatically syncs to the watch app
- When authentication state changes on the watch app, it automatically syncs back to the iOS app
- Both apps can make authenticated API requests without requiring separate sign-in

## Setup

### 1. Create a Clerk application

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk Dashboard
3. Copy your **Publishable Key** from the API Keys section

### 2. Configure Watch Connectivity

Both your iOS app and watchOS app must be configured with Watch Connectivity:

1. In Xcode, select your iOS app target (WatchExampleApp)
2. Go to **Signing & Capabilities**
3. Add the **Watch Connectivity** capability (if not already present)
4. Ensure the watchOS app target has the companion capability enabled

### 3. Add Your Publishable Key

1. Open `WatchExampleApp/WatchExampleApp.swift`
2. Replace `"pk_test_..."` with your actual Clerk publishable key
3. Open `WatchExampleApp Watch App/WatchExampleApp.swift`
4. Replace `"pk_test_..."` with the same publishable key

### 4. Enable Watch Connectivity Sync

Both apps need to enable Watch Connectivity sync by setting `watchConnectivityEnabled: true`:

```swift
let options = Clerk.Options(
  watchConnectivityEnabled: true
)

Clerk.configure(
  publishableKey: "YOUR_PUBLISHABLE_KEY",
  options: options
)
```

## Running the Example

**Important:** Both apps must be installed for Watch Connectivity to work.

1. Select the **WatchExampleApp** scheme from the workspace navigator
2. Build and run the **iOS app first** - this installs the companion app
3. Then build and run the **watchOS app** - it will connect to the iOS app
4. Sign in on either app - authentication state will automatically sync bidirectionally between both apps
5. Both apps will automatically use the synced authentication state for API requests

**Note:** If you see "WCSession counterpart app not installed" errors, make sure the iOS app is installed before running the watch app.

**Note:** When running in the simulator, make sure you have a simulator with a paired Apple Watch setup. You can create a paired watch simulator in Xcode by going to **Window > Devices and Simulators** and adding a watch simulator paired to your iPhone simulator.

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 16.0+
- Both apps must be signed with the same Team ID
- Apple Watch must be paired with the iPhone
