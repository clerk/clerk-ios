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
    let options = Clerk.ClerkOptions(
      watchConnectivityEnabled: true
    )

    Clerk.configure(
      publishableKey: "YOUR_PUBLISHABLE_KEY",
      options: options
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
    }
  }
}
