# MacExampleApp

This example is a native macOS harness for validating the Clerk package without going through Mac Catalyst.

## Overview

This example demonstrates how to:

- Configure Clerk in a native macOS SwiftUI app
- Inspect current Clerk environment, client, session, and user state
- Trigger environment and client refreshes from a native macOS app
- Keep a ready-to-run macOS target in place while `ClerkKitUI` macOS support is added

`ClerkKitUI` is still linked into the example project, but the current prebuilt views such as `AuthView` and `UserButton` are iOS-only.

## Setup

### 1. Create a Clerk application

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk Dashboard
3. Copy your **Publishable Key** from the API Keys section

### 2. Add Local Secrets

1. From the repo root, run `make setup` (or `make create-example-local-secrets-plists`) if you need to regenerate example secrets files.
2. Set `CLERK_PUBLISHABLE_KEY` in `Examples/MacExampleApp/MacExampleApp/LocalSecrets.plist`.

`LocalSecrets.plist` is gitignored, so it will not be committed.

You can also provide the same key as a Run environment variable (`CLERK_PUBLISHABLE_KEY`). Environment variables take precedence over `LocalSecrets.plist`.

## Running the Example

1. Open `Clerk.xcworkspace`
2. Select the **MacExampleApp** scheme
3. Choose the **My Mac** run destination
4. Build and run the project

## Requirements

- macOS 14.0+
- Xcode 16.0+
