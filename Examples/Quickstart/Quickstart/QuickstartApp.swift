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
    Clerk.configure(publishableKey: "YOUR_PUBLISHABLE_KEY")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
    }
  }
}
