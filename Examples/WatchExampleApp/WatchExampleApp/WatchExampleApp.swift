//
//  WatchExampleApp.swift
//  WatchExampleApp
//
//  Created on 2025-01-27.
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct WatchExampleApp: App {
  init() {
    // Configure Clerk with Watch Connectivity sync enabled
    let options = Clerk.ClerkOptions(
      logLevel: .debug,
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
        .task {
          do {
            try await Clerk.shared.load()
          } catch {
            dump(error)
          }
        }
    }
  }
}
