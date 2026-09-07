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
    let publishableKey = QuickstartLocalSecrets.load().publishableKey ?? ""
    Clerk.configure(publishableKey: publishableKey)
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
