//
//  QuickstartApp.swift
//  Quickstart
//
//  Created by Mike Pitre on 7/30/25.
//

import ClerkKit
import SwiftUI

@main
struct QuickstartApp: App {

  init() {
    Clerk.configure(
      publishableKey: "YOUR_PUBLISHABLE_KEY",
      options: .init(logLevel: .debug)
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .task {
          try? await Clerk.shared.load()
        }
        #if DEBUG
        .task { Atlantis.start() }
        #endif
    }
  }
}
