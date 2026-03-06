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
    let options = Clerk.Options(
      watchConnectivityEnabled: true
    )

    Clerk.configure(
      publishableKey: WatchExampleLocalSecrets.load().publishableKey ?? "",
      options: options
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .prefetchClerkImages()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
  }
}
