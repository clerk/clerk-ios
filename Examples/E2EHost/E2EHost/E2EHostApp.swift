//
//  E2EHostApp.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct E2EHostApp: App {
  private let configuration = E2EConfiguration()
  private let configurationFailure: VerifyState.Failure?

  init() {
    // A verify launch passes arguments, not environment, and ClerkKitUI reads this
    // variable to keep password AutoFill prompts from covering the form.
    if configuration.launchId != nil {
      setenv("CLERK_E2E_MODE", "1", 1)
    }

    configurationFailure = configuration.publishableKeyFailure

    if let configurationFailure {
      VerifyState(
        configuration: configuration,
        screen: "error",
        clerk: nil,
        ticket: configuration.signInTicket == nil ? .none : .failed,
        lastError: configurationFailure
      ).log()
    } else {
      Clerk.configure(
        publishableKey: configuration.publishableKey,
        options: configuration.clerkOptions
      )
    }
  }

  var body: some Scene {
    WindowGroup {
      if let configurationFailure {
        LaunchErrorView(failure: configurationFailure)
      } else {
        E2EHostView(configuration: configuration)
          .prefetchClerkImages()
          .environment(Clerk.shared)
      }
    }
  }
}
