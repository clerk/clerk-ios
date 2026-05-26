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
  @State private var cleanupDidComplete = false
  @State private var e2eOAuthProviderDidConnect = false

  init(configuration: E2EConfiguration) {
    self.configuration = configuration
  }

  var body: some View {
    VStack(spacing: 24) {
      UserButton(signedOutContent: {
        Button("Sign in") {
          authViewIsPresented = true
        }
      })

      e2eControls
    }
    .onReceive(NotificationCenter.default.publisher(for: .e2eCleanupAccountRequested)) { _ in
      cleanupAccount()
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView(mode: configuration.authMode)
        .persistsIdentifiers(false)
    }
  }

  @ViewBuilder
  private var e2eControls: some View {
    if cleanupDidComplete {
      Text("Cleanup complete")
        .accessibilityIdentifier(E2EIdentifiers.Auth.cleanupComplete)
    }

    if clerk.user != nil {
      Text("Signed in")
        .accessibilityIdentifier(E2EIdentifiers.Auth.signedIn)

      sessionState

      Button("Sign out") {
        signOut()
      }
      .accessibilityIdentifier(E2EIdentifiers.Auth.signOut)

      if clerk.session?.status == .active {
        if e2eOAuthProviderDidConnect {
          Text("E2E OAuth connected")
            .accessibilityIdentifier(E2EIdentifiers.Auth.e2eOAuthConnected)
        }

        Button("Connect E2E OAuth Provider") {
          connectE2EOAuthProvider()
        }
        .accessibilityIdentifier(E2EIdentifiers.Auth.connectE2EOAuthProvider)

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
        .accessibilityIdentifier(E2EIdentifiers.Auth.sessionStatus)

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

  private func signOut() {
    Task {
      try? await clerk.auth.signOut()
      authViewIsPresented = false
    }
  }

  private func deleteAccount() {
    Task { @MainActor in
      await deleteCurrentAccountIfPresent()
    }
  }

  private func cleanupAccount() {
    Task { @MainActor in
      guard await deleteCurrentAccountIfPresent() else { return }
      cleanupDidComplete = true
    }
  }

  @discardableResult
  @MainActor
  private func deleteCurrentAccountIfPresent() async -> Bool {
    guard let user = clerk.user else {
      authViewIsPresented = false
      return true
    }

    guard await (try? user.delete()) != nil else {
      return false
    }

    try? await clerk.auth.signOut()
    authViewIsPresented = false
    return true
  }

  private func connectE2EOAuthProvider() {
    Task { @MainActor in
      guard let user = clerk.user else { return }

      do {
        let account = try await user.createExternalAccount(provider: .custom("oauth_custom_e2e_oauth_provider"))
        try await account.reauthorize()
        e2eOAuthProviderDidConnect = true
      } catch {
        print("Failed to connect E2E OAuth provider: \(error)")
      }
    }
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
