# Purchases

This is a starting template for integrating Clerk authentication with purchases/subscriptions in an iOS application. Build upon this foundation to create your own authentication-gated purchase flows.

## Overview

This template provides:

- Basic Clerk iOS SDK configuration in a SwiftUI application
- Boilerplate SwiftUI view structure
- Foundation for implementing authentication-gated purchases
- Starting point for creating premium plan interfaces

## Setup

### 1. Create a Clerk application

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk Dashboard
3. Copy your **Publishable Key** from the API Keys section

### 2. Configure the Example

1. Open `PurchasesApp.swift`
2. Replace `"YOUR_PUBLISHABLE_KEY"` with your actual Clerk publishable key:

```swift
clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
```

### 3. Run the App

1. Select the **Purchases** scheme from the workspace navigator
2. Choose your target device/simulator
3. Build and run the project (⌘+R)

## Features

- **Authentication Flow**: Users must sign in before viewing purchase options
- **Plan Selection**: Visual cards displaying different subscription tiers
- **User Profile**: Authenticated users can manage their account
- **Purchase Integration**: Ready-to-integrate purchase handling (placeholder implementation)

## Integration Notes

This example provides the UI framework for a purchases flow. To complete the integration, you would typically:

1. Integrate with a payment processor (Stripe, RevenueCat, etc.)
2. Connect purchase events to your backend
3. Implement subscription status tracking
4. Add purchase confirmation and receipt handling
