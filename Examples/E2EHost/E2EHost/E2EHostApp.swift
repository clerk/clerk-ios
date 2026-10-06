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
        ConfigurationFailureView(configuration: configuration, failure: configurationFailure)
      } else {
        E2EHostView(configuration: configuration)
          .prefetchClerkImages()
          .environment(Clerk.shared)
      }
    }
  }
}

private struct ConfigurationFailureView: View {
  let configuration: E2EConfiguration
  let failure: VerifyState.Failure

  @State private var ticket: VerifyState.Ticket

  init(configuration: E2EConfiguration, failure: VerifyState.Failure) {
    self.configuration = configuration
    self.failure = failure
    _ticket = State(initialValue: configuration.signInTicket == nil ? .none : .pending)
  }

  var body: some View {
    VStack(spacing: 0) {
      Text(failure.message)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      VerifyStateFooter(state: VerifyState(
        configuration: configuration,
        screen: "error",
        clerk: nil,
        ticket: ticket,
        lastError: failure
      ))
    }
    .task {
      if ticket == .pending {
        ticket = .failed
      }
    }
  }
}
