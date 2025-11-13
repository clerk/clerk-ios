# WatchExampleApp

This example demonstrates how to sync authentication state from an iOS app to its companion Apple Watch app using Clerk's Watch Connectivity integration.

## Overview

This example consists of two apps:

- **iOS App** - Handles authentication (sign-in/sign-up) using Clerk's UI components and automatically syncs authentication state (deviceToken, Client, Environment) to the watch app
- **watchOS App** - Receives synced authentication state via Watch Connectivity and uses it automatically

This example shows how to:

- Enable Watch Connectivity sync using the `watchConnectivityEnabled` option
- Automatically sync deviceToken, Client, and Environment from iOS to watchOS when they change
- Use the synced authentication state in watchOS app API requests
- Display user information on Apple Watch using synced authentication state

## Architecture

When a user signs in on the iOS app:

1. The deviceToken, Client, and Environment are stored in the iOS app's keychain
2. If `watchConnectivityEnabled` is enabled, the deviceToken, Client, and Environment are automatically sent to the watch app via Watch Connectivity
3. The watch app receives the data and stores it in its own keychain (with conflict resolution for Client using timestamps)
4. The watch app automatically uses the deviceToken in all API requests via `ClerkHeaderRequestMiddleware`
5. The watch app loads synced Client and Environment immediately on launch

The sync happens:
- On app launch (after `Clerk.shared.load()` completes)
- When the app enters the foreground
- When the deviceToken changes (via `ClerkDeviceTokenResponseMiddleware`)
- When the Client changes (via `Clerk.client` didSet)
- When the Environment changes (via `Clerk.environment` didSet)

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

### 3. Configure Clerk in the iOS App

Enable Watch Connectivity sync by setting `watchConnectivityEnabled: true`:

```swift
let options = Clerk.ClerkOptions(
  watchConnectivityEnabled: true
)

Clerk.configure(
  publishableKey: "YOUR_PUBLISHABLE_KEY",
  options: options
)
```

### 4. Configure Clerk in the watchOS App

Enable Watch Connectivity sync by setting `watchConnectivityEnabled: true`:

```swift
let options = Clerk.ClerkOptions(
  watchConnectivityEnabled: true
)

Clerk.configure(
  publishableKey: "YOUR_PUBLISHABLE_KEY",
  options: options
)
```

### 5. Update the Example

1. Open `WatchExampleApp/WatchExampleApp.swift`
2. Replace `"pk_test_..."` with your actual Clerk publishable key
3. Open `WatchExampleApp Watch App/WatchExampleApp.swift`
4. Replace `"pk_test_..."` with the same publishable key

### 6. Run the Apps

**Important:** Both apps must be installed for Watch Connectivity to work.

1. Select the **WatchExampleApp** scheme from the workspace navigator
2. Build and run the **iOS app first** - this installs the companion app
3. Then build and run the **watchOS app** - it will connect to the iOS app
4. Sign in on the iOS app - authentication state (deviceToken, Client, Environment) will automatically sync to the watch
5. The watch app will receive and use the synced authentication state for API requests

**Note:** If you see "WCSession counterpart app not installed" errors, make sure the iOS app is installed before running the watch app.

## How It Works

1. **iOS App Side:**
   - When `watchConnectivityEnabled: true` is set, `WatchConnectivityManager` is initialized
   - The manager activates a WCSession and sends deviceToken, Client, and Environment updates via `updateApplicationContext`
   - Sync happens automatically on launch, foreground, and when deviceToken/Client/Environment changes

2. **watchOS App Side:**
   - When `watchConnectivityEnabled: true` is set, `WatchSyncReceiver` is automatically initialized
   - The receiver sets up a WCSession delegate to receive updates from the iOS app
   - When data is received, it's stored in the watch app's keychain
   - For Client, conflict resolution uses timestamps (iOS takes priority - only newer or equal timestamps are accepted)
   - For Environment, iOS always wins (no conflict resolution needed)
   - Synced Client and Environment are loaded immediately on watch app launch via `CacheManager`
   - `ClerkHeaderRequestMiddleware` automatically reads the deviceToken from keychain and includes it in API requests

3. **Automatic Token Usage:**
   - The watch app doesn't need to manually handle the token
   - All API requests made through Clerk automatically include the Authorization header
   - The token is read from keychain on each request

## Key Differences from Keychain Sharing

This example uses **Watch Connectivity** instead of **Keychain Sharing**:

- **Watch Connectivity**: Actively syncs authentication state (deviceToken, Client, Environment) when it changes, works even if watch app isn't running
- **Keychain Sharing**: Requires both apps to access the same keychain, but doesn't actively sync changes

Watch Connectivity is recommended for real-time token synchronization, while Keychain Sharing is better for static shared data.

## Requirements

- iOS 14.0+
- watchOS 7.0+
- Xcode 14.0+
- Both apps must be signed with the same Team ID
- Apple Watch must be paired with the iPhone

