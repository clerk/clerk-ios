//
//  QuickstartApp.swift
//  Quickstart
//
//  Created by Mike Pitre on 7/30/25.
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct QuickstartApp: App {
  init() {
    Clerk.configure(publishableKey: "pk_test_ZHJpdmVuLWdhdG9yLTUwLmNsZXJrLmFjY291bnRzLmRldiQ")
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
