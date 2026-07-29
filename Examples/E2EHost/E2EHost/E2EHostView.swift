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

  init(configuration: E2EConfiguration) {
    self.configuration = configuration
  }

  var body: some View {
    VStack(spacing: 24) {
      UserButton(signedOutContent: {
        Button("Sign in") {
          authViewIsPresented = true
        }
        .accessibilityIdentifier(E2EIdentifiers.Auth.signIn)
      })

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
          .accessibilityIdentifier(E2EIdentifiers.Auth.userID)
      }

      sessionState

      Button("Sign out") {
        signOut()
      }
      .accessibilityIdentifier(E2EIdentifiers.Auth.signOut)

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
