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
      publishableKey: "pk_test_YW11c2luZy1iYXJuYWNsZS0yNi5jbGVyay5hY2NvdW50cy5kZXYk",
      options: .init(logLevel: .debug)
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .task { try? await Clerk.shared.load() }
    }
  }
}
