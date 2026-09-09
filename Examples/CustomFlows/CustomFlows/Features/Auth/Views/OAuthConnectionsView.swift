//
//  OAuthConnectionsView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct OAuthConnectionsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var showDocs = false

  var body: some View {
    Form {
      Section {
        Button("Sign In with Google") {
          Task {
            await handleSignIn(provider: .oauthGoogle)
          }
        }

        Button("Sign In with GitHub") {
          Task {
            await handleSignIn(provider: .oauthGithub)
          }
        }
      }
    }
    .navigationTitle("Sign In with OAuth")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showDocs = true
        } label: {
          Image(systemName: "book")
        }
      }
    }
    .sheet(isPresented: $showDocs) {
      if let url = AuthFlow.oauthConnections.documentationURL {
        SafariView(url: url)
      }
    }
  }

  private func handleSignIn(provider: SignInSSOParamsStrategy) async {
    do {
      let result = try await clerk.authenticateWithSSO(.init(strategy: provider, start: .signIn, transferable: true))
      switch result {
      case .case1(let value):
        if value.signIn.status == .complete {
          try await value.signIn.finalize()
        } else {
          feedback.continuation = .signIn
        }
      case .case2(let value):
        if value.signUp.status == .complete {
          try await value.signUp.finalize()
        } else {
          feedback.continuation = .signUp
        }
      }
    } catch {
      feedback.error = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    OAuthConnectionsView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
