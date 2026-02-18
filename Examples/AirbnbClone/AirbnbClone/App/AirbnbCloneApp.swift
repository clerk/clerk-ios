//
//  AirbnbCloneApp.swift
//  AirbnbClone
//

import ClerkKit
import SwiftUI

@main
struct AirbnbCloneApp: App {
  init() {
    Clerk.configure(publishableKey: AirbnbCloneLocalSecrets.load().publishableKey ?? "")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
  }
}
