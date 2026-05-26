//
//  E2EHostApp.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct E2EHostApp: App {
  private let configuration = E2EConfiguration()

  init() {
    Clerk.configure(
      publishableKey: configuration.publishableKey,
      options: configuration.clerkOptions
    )
    E2ECleanupCommand.startObserving()
  }

  var body: some Scene {
    WindowGroup {
      E2EHostView(configuration: configuration)
        .prefetchClerkImages()
        .environment(Clerk.shared)
    }
  }
}
