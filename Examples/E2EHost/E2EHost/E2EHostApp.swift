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
    configurationFailure = configuration.publishableKeyFailure

    if configurationFailure == nil {
      Clerk.configure(
        publishableKey: configuration.publishableKey,
        options: configuration.clerkOptions
      )
    }
  }

  var body: some Scene {
    WindowGroup {
      if let configurationFailure {
        Text(configurationFailure.message)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .safeAreaInset(edge: .bottom) {
            VerifyStateFooter(state: VerifyState(
              configuration: configuration,
              screen: "error",
              clerk: nil,
              ticket: configuration.signInTicket == nil ? .none : .failed,
              lastError: configurationFailure
            ))
          }
      } else {
        E2EHostView(configuration: configuration)
          .prefetchClerkImages()
          .environment(Clerk.shared)
      }
    }
  }
}
