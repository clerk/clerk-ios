# ClerkRevCat

A demonstration app showcasing the integration of Clerk authentication with RevenueCat for subscription management in iOS. This example demonstrates how to gate premium content behind authentication and subscriptions.

## Setup

### 1. Create a Clerk Application

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk Dashboard
3. Copy your **Publishable Key** from the API Keys section

### 2. Create a RevenueCat Project

Follow the [RevenueCat SDK Quickstart](https://www.revenuecat.com/docs/getting-started/quickstart) for detailed setup instructions:

1. Sign up for a RevenueCat account at [revenuecat.com](https://revenuecat.com)
2. Create a new project in your RevenueCat Dashboard
3. Copy your **Public API Key** from the API Keys section
4. Configure your products and offerings in the RevenueCat Dashboard

### 3. Configure the Example

1. Open `ClerkRevCatApp.swift`
2. Replace `"YOUR_PUBLISHABLE_KEY"` with your actual Clerk publishable key:

```swift
clerk.configure(publishableKey: "YOUR_ACTUAL_CLERK_PUBLISHABLE_KEY")
```

3. Open `RevenueCatManager.swift`
4. Replace `"YOUR_REVENUECAT_API_KEY"` with your actual RevenueCat public API key:

```swift
Purchases.configure(withAPIKey: "YOUR_ACTUAL_REVENUECAT_API_KEY")
```

### 4. Set Up App Store Connect (For Testing Purchases)

1. Create your app in App Store Connect
2. Set up your subscription products that match your RevenueCat configuration
3. Create a sandbox tester account for testing purchases

### 5. Run the App

1. Select the **ClerkRevCat** scheme from the workspace navigator
2. Choose your target device/simulator
3. Build and run the project (⌘+R)

## Testing

### Sandbox Testing

1. Use a sandbox Apple ID to test purchases
2. Ensure your RevenueCat project is configured with your App Store Connect products
3. Test the complete flow: sign up → view premium content → purchase subscription → access premium content
