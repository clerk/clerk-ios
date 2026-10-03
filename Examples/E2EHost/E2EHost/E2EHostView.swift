//
//  E2EHostView.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct E2EHostView: View {
  @Environment(Clerk.self) private var clerk

  let configuration: E2EConfiguration

  @State private var authViewIsPresented = false
  @State private var ticket: VerifyState.Ticket
  @State private var lastError: VerifyState.Failure?

  init(configuration: E2EConfiguration) {
    self.configuration = configuration
    _ticket = State(initialValue: configuration.signInTicket == nil ? .none : .pending)
  }

  var body: some View {
    VStack(spacing: 0) {
      routedScreen
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      VerifyStateFooter(state: VerifyState(
        configuration: configuration,
        screen: renderedScreen?.rawValue ?? "launching",
        clerk: clerk,
        ticket: ticket,
        lastError: lastError ?? configuration.screenFailure
      ))
    }
    .task {
      await launch()
    }
  }

  private var renderedScreen: VerifyScreen? {
    if ticket == .pending {
      return nil
    }

    if configuration.screen == .auth, clerk.isAuthFlowComplete {
      return .home
    }

    return configuration.screen
  }

  @ViewBuilder
  private var routedScreen: some View {
    switch renderedScreen {
    case nil:
      ProgressView()
    case .home:
      home
    case .auth:
      AuthView(mode: configuration.authMode, isDismissible: false)
        .persistsIdentifiers(false)
    case .userProfile:
      UserProfileView(isDismissible: false)
    case .orgSwitcher:
      OrganizationSwitcher()
    case .orgList:
      OrganizationListView(isDismissible: false)
    case .orgProfile:
      OrganizationProfileView(isDismissible: false)
    }
  }

  private var home: some View {
    VStack(spacing: 24) {
      UserButton(signedOutContent: {
        Button("Sign in") {
          authViewIsPresented = true
        }
        .accessibilityIdentifier(E2EIdentifiers.Auth.signIn)
      })

      OrganizationSwitcher()

      e2eControls
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView(mode: configuration.authMode)
        .persistsIdentifiers(false)
    }
  }

  @ViewBuilder
  private var e2eControls: some View {
    if clerk.user != nil {
      Text("Signed in")
        .accessibilityIdentifier(E2EIdentifiers.Auth.signedIn)

      if let userID = clerk.user?.id {
        Text(userID)
          .accessibilityIdentifier(E2EIdentifiers.Verify.userId)
      }

      sessionState

      Button("Sign out") {
        signOut()
      }
      .accessibilityIdentifier(E2EIdentifiers.Verify.signOut)

      if clerk.session?.status == .active {
        Button("Delete account", role: .destructive) {
          deleteAccount()
        }
        .accessibilityIdentifier(E2EIdentifiers.Auth.deleteAccount)
      }
    } else {
      Text("Signed out")
        .accessibilityIdentifier(E2EIdentifiers.Auth.signedOut)
    }
  }

  @ViewBuilder
  private var sessionState: some View {
    if let session = clerk.session {
      Text(session.status.rawValue)

      switch session.status {
      case .active:
        Text("Session active")
          .accessibilityIdentifier(E2EIdentifiers.Auth.sessionActive)
      case .pending:
        Text("Session pending")
          .accessibilityIdentifier(E2EIdentifiers.Auth.sessionPending)
      default:
        EmptyView()
      }

      let tasks = session.tasks ?? []
      if !tasks.isEmpty {
        Text(tasks.map(\.rawValue).joined(separator: ","))
          .accessibilityIdentifier(E2EIdentifiers.Auth.pendingTasks)
      }
    }
  }

  private func launch() async {
    do {
      try await clerk.refreshEnvironment()
    } catch {
      lastError = .init(error, fallbackCode: "environment_load_failed")
    }

    guard ticket == .pending, let signInTicket = configuration.signInTicket else {
      return
    }

    guard lastError == nil else {
      ticket = .failed
      return
    }

    do {
      _ = try await clerk.auth.signInWithTicket(signInTicket)
      ticket = .succeeded
    } catch {
      lastError = .init(error, fallbackCode: "ticket_sign_in_failed")
      ticket = .failed
    }
  }

  private func signOut() {
    Task {
      try? await clerk.auth.signOut()
      authViewIsPresented = false
    }
  }

  private func deleteAccount() {
    Task { @MainActor in
      try? await deleteCurrentAccountIfPresent()
    }
  }

  @MainActor
  private func deleteCurrentAccountIfPresent() async throws {
    guard let user = clerk.user else {
      authViewIsPresented = false
      return
    }

    try await user.delete()
    try? await clerk.auth.signOut()
    authViewIsPresented = false
  }
}

#Preview("Signed Out") {
  E2EHostView(configuration: .mock)
    .environment(Clerk.preview { preview in
      preview.isSignedIn = false
    })
}

#Preview("Signed In") {
  E2EHostView(configuration: .mock)
    .environment(Clerk.preview())
}
