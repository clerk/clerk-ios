//
//  AirbnbCloneApp.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

@main
struct AirbnbCloneApp: App {
  init() {
    Clerk.configure(publishableKey: "pk_test_dGFsZW50ZWQta3JpbGwtNjMuY2xlcmsuYWNjb3VudHMuZGV2JA")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(Clerk.shared)
        .atlantisProxy()
    }
  }
}
