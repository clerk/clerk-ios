//
//  WatchExampleApp.swift
//  WatchExampleApp
//
//  Created on 2025-01-27.
//

import ClerkKit
import ClerkKitUI
import SwiftUI

private let sharedSessionKeychainService = "com.clerk.shared-session-sync.examples"
private let sharedSessionKeychainAccessGroup = "L8SD6SB282.com.clerk.shared-session-sync.examples"

@main
struct WatchExampleApp: App {
  init() {
    let options = Clerk.Options(
      keychainConfig: .init(
        service: sharedSessionKeychainService,
        accessGroup: sharedSessionKeychainAccessGroup
      ),
      watchConnectivityEnabled: true,
      sharedSessionSync: .enabled
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
