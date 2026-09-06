//
//  QuickstartApp.swift
//  Quickstart
//

import ClerkJSCore
import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct QuickstartApp: App {
  @State private var jsClerk: ClerkJSCore.Clerk

  init() {
    let publishableKey = QuickstartLocalSecrets.load().publishableKey ?? ""
    ClerkKit.Clerk.configure(publishableKey: publishableKey)
    _jsClerk = State(initialValue: ClerkJSCore.Clerk.persistent(publishableKey: publishableKey))
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .prefetchClerkImages()
        .environment(ClerkKit.Clerk.shared)
        .environment(jsClerk)
        .task {
          try? await jsClerk.load()
        }
        .atlantisProxy()
    }
  }
}
