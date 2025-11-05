//
//  AppleWatchExampleApp.swift
//  AppleWatchExample Watch App
//
//  Created by Mike Pitre on 7/30/25.
//

import ClerkKit
import SwiftUI

@main
struct AppleWatchExampleWatchApp: App {

  init() {
    // Configure Clerk with the same shared access group as the iOS app
    // This allows the watch app to access the authentication state stored by the iOS app
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

