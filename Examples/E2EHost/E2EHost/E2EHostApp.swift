//
//  E2EHostApp.swift
//  E2EHost
//

import ClerkJSCore
import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct E2EHostApp: App {
  private let configuration = E2EConfiguration()
  @State private var jsClerk: ClerkJSCore.Clerk

  init() {
    ClerkKit.Clerk.configure(
      publishableKey: configuration.publishableKey,
      options: configuration.clerkOptions
    )
    _jsClerk = State(initialValue: ClerkJSCore.Clerk.persistent(publishableKey: configuration.publishableKey))
  }

  var body: some Scene {
    WindowGroup {
      E2EHostView(configuration: configuration)
        .prefetchClerkImages()
        .environment(ClerkKit.Clerk.shared)
        .environment(jsClerk)
        .task {
          try? await jsClerk.load()
        }
    }
  }
}
