//
//  CustomFlowsApp.swift
//  CustomFlows
//

import ClerkKit
import SwiftUI

@main
struct CustomFlowsApp: App {
  init() {
    Clerk.configure(publishableKey: CustomFlowsLocalSecrets.load().publishableKey ?? "")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
  }
}
