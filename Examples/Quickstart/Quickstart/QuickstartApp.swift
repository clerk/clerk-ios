//
//  QuickstartApp.swift
//  Quickstart
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct QuickstartApp: App {
  init() {
    Clerk.configure(publishableKey: QuickstartLocalSecrets.load().publishableKey ?? "")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .clerkRootView()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
  }
}
