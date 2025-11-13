//
//  WatchExampleApp.swift
//  WatchExampleApp Watch App
//
//  Created on 2025-01-27.
//

import ClerkKit
import SwiftUI

@main
struct WatchExampleAppWatchApp: App {

  init() {
    // Configure Clerk with Watch Connectivity sync enabled
    // This will automatically receive deviceToken from the iOS app and store it in keychain
    let options = Clerk.ClerkOptions(
      debugMode: true,
      watchConnectivityEnabled: true
    )

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
