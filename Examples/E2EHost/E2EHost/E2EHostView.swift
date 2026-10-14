//
//  E2EHostView.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct E2EHostView: View {
  private enum Launch: Equatable {
    case loading
    case ready(VerifyState.Ticket)
    case failed(VerifyState.Failure)
  }

  private enum Destination {
    case authView
    case customSignIn
  }

  private enum Screen {
    case loading
    case error(VerifyState.Failure)
    case home
    case auth
    case customSignIn

    var name: String {
      switch self {
      case .loading: "launching"
      case .error: "error"
      case .home: "home"
      case .auth: "auth"
      case .customSignIn: "customSignIn"
      }
    }
  }

  @Environment(Clerk.self) private var clerk

  let configuration: E2EConfiguration

  @State private var launch = Launch.loading
  @State private var authViewIsPresented = false
  @State private var destination: Destination?

  init(configuration: E2EConfiguration) {
    self.configuration = configuration
  }

  var body: some View {
    content
      .task {
        await start()
      }
      .onChange(of: verifyState, initial: true) {
        verifyState.log()
      }
      .onChange(of: clerk.isAuthFlowComplete) { _, isComplete in
        if isComplete, destination == .authView {
          destination = nil
        }
      }
  }

  private var screen: Screen {
    switch launch {
    case .loading:
      .loading
    case .failed(let failure):
      .error(failure)
    case .ready:
      switch destination {
      case .authView? where !clerk.isAuthFlowComplete: .auth
      case .customSignIn?: .customSignIn
      default: .home
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch screen {
    case .loading:
      ProgressView()
    case .error(let failure):
      LaunchErrorView(failure: failure)
    case .home:
      home
    case .auth:
      authView
    case .customSignIn:
      CustomSignInView {
        destination = nil
      }
    }
  }

  private var authView: AuthView {
    let authView = AuthView(mode: configuration.authMode, isDismissible: false)
      .persistsIdentifiers(false)

    return configuration.initialIdentifier.map(authView.initialIdentifier) ?? authView
  }

  private var home: some View {
    VStack(spacing: 24) {
      if let session = clerk.session, session.status == .active, let user = clerk.user {
        UserButton()

        VStack(spacing: 4) {
          Text(user.primaryEmailAddress.map { "Signed in as \($0.emailAddress)" } ?? "Signed in")
            .multilineTextAlignment(.center)
            .accessibilityIdentifier(E2EIdentifiers.Auth.signedIn)

          Group {
            HStack(spacing: 4) {
              Text("User ID")

              Text(user.id)
                .accessibilityIdentifier(E2EIdentifiers.Auth.userId)
            }

            HStack(spacing: 4) {
              Text("Session ID")

              Text(session.id)
                .accessibilityIdentifier(E2EIdentifiers.Auth.sessionId)
            }
          }
          .font(.footnote)
          .foregroundStyle(.secondary)
        }

        OrganizationSwitcher()

        Button("Sign out") {
          Task {
            try? await clerk.auth.signOut()
          }
        }
        .accessibilityIdentifier(E2EIdentifiers.Auth.signOut)
      } else {
        Text("Signed out")
          .accessibilityIdentifier(E2EIdentifiers.Auth.signedOut)

        Button("Sign in") {
          authViewIsPresented = true
        }
        .accessibilityIdentifier(E2EIdentifiers.Auth.signIn)

        Button("Sign in full screen") {
          destination = .authView
        }
        .accessibilityIdentifier(E2EIdentifiers.Auth.signInFullScreen)

        Button("Custom sign-in") {
          destination = .customSignIn
        }
        .accessibilityIdentifier(E2EIdentifiers.Home.customSignIn)
      }
    }
    .padding()
    .sheet(isPresented: $authViewIsPresented) {
      AuthView(mode: configuration.authMode)
        .persistsIdentifiers(false)
    }
  }

  private var verifyState: VerifyState {
    let ticket: VerifyState.Ticket = switch launch {
    case .loading: configuration.signInTicket == nil ? .none : .pending
    case .ready(let outcome): outcome
    case .failed: configuration.signInTicket == nil ? .none : .failed
    }
    let lastError: VerifyState.Failure? = if case .failed(let failure) = launch { failure } else { nil }

    return VerifyState(
      configuration: configuration,
      screen: screen.name,
      clerk: clerk,
      ticket: ticket,
      lastError: lastError
    )
  }

  private func start() async {
    guard launch == .loading else {
      return
    }

    do {
      try await clerk.refreshEnvironment()
    } catch {
      launch = .failed(.init(error, fallbackCode: "environment_load_failed"))
      return
    }

    guard let signInTicket = configuration.signInTicket, clerk.session == nil else {
      launch = .ready(.none)
      return
    }

    do {
      _ = try await clerk.auth.signInWithTicket(signInTicket)
    } catch {
      launch = .failed(.init(error, fallbackCode: "ticket_sign_in_failed"))
      return
    }

    launch = .ready(.succeeded)
  }
}

struct LaunchErrorView: View {
  let failure: VerifyState.Failure

  var body: some View {
    VStack(spacing: 12) {
      Text("Something went wrong")
        .font(.headline)

      Text(failure.message)
        .multilineTextAlignment(.center)
    }
    .padding()
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(E2EIdentifiers.Launch.error)
  }
}
