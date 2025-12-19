//
//  CustomFlowsApp.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

@main
struct CustomFlowsApp: App {
  init() {
    Clerk.configure(publishableKey: "pk_test_YW11c2luZy1iYXJuYWNsZS0yNi5jbGVyay5hY2NvdW50cy5kZXYk")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
  }
}
