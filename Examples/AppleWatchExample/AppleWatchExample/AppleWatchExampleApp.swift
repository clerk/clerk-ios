//
//  AppleWatchExampleApp.swift
//  AppleWatchExample
//
//  Created by Mike Pitre on 7/30/25.
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct AppleWatchExampleApp: App {

  init() {
    // Configure Clerk with a shared access group to enable auth state sharing
    // between the iOS app and watchOS app. Both apps must use the same access group.
    let keychainConfig = KeychainConfig(
      accessGroup: "group.com.clerk.AppleWatchExample"
    )
    let options = Clerk.ClerkOptions(keychainConfig: keychainConfig)

    Clerk.configure(
      publishableKey: "pk_test_YW11c2luZy1iYXJuYWNsZS0yNi5jbGVyay5hY2NvdW50cy5kZXYk",
      options: options
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .task { try? await Clerk.shared.load() }
    }
  }
}
