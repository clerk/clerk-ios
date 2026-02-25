# Quickstart

This is a companion project to the [iOS Quickstart guide](https://clerk.com/docs/quickstarts/ios). It demonstrates basic use of the [Clerk iOS Components](https://clerk.com/docs/references/ios/auth-view).

## Overview

This quickstart example demonstrates how to use the Prebuilt Clerk Views:

- Configure the Clerk iOS SDK in a SwiftUI application
- Implement sign-in and sign-up flows using Clerk's pre-built components
- Handle authenticated and unauthenticated states
- Display the user profile and account management options

## Setup

### 1. Create a Clerk application

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk Dashboard
3. Copy your **Publishable Key** from the API Keys section

### 2. Add Local Secrets (one-time)

1. From the repo root, run `make setup` (or `make create-example-local-secrets-plists`) to generate `Examples/Quickstart/Quickstart/LocalSecrets.plist` from the template.
2. Set your values in `Examples/Quickstart/Quickstart/LocalSecrets.plist`:
   - `CLERK_PUBLISHABLE_KEY`

`LocalSecrets.plist` is gitignored, so it will not be committed.

You can also provide the same keys as Run environment variables in the scheme. Environment variables take precedence over `LocalSecrets.plist`.

## Running the Example

1. Select the **Quickstart** scheme from the workspace navigator
2. Choose your target device/simulator
3. Build and run the project (⌘+R)
