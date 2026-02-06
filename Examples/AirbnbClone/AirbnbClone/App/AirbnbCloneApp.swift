//
//  AirbnbCloneApp.swift
//  AirbnbClone
//

import ClerkKit
import SwiftUI

@main
struct AirbnbCloneApp: App {
  init() {
    Clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
  }
}
