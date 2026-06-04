//
//  MacExampleApp.swift
//  MacExampleApp
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct MacExampleApp: App {
  init() {
    Clerk.configure(publishableKey: MacExampleLocalSecrets.load().publishableKey ?? "")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .prefetchClerkImages()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
    .defaultSize(width: 1100, height: 800)
  }
}
