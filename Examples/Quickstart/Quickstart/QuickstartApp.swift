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
    Clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
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
