//
//  OAuthConnectionsView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct OAuthConnectionsView: View {
  @Environment(Clerk.self) private var clerk
  @State private var showDocs = false

  var body: some View {
    Form {
      Section {
        Button("Sign In with Google") {
          Task {
            await handleSignIn(provider: .google)
          }
        }

        Button("Sign In with GitHub") {
          Task {
            await handleSignIn(provider: .github)
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

  private func handleSignIn(provider: OAuthProvider) async {
    do {
      let result = try await clerk.auth.signInWithOAuth(provider: provider)
      switch result {
      case .signIn(let signIn):
        switch signIn.status {
        case .complete:
          dump(clerk.session)
        default:
          dump(signIn.status)
        }
      case .signUp(let signUp):
        dump(signUp.status)
      }
    } catch {
      dump(error)
    }
  }
}

#Preview {
  NavigationStack {
    OAuthConnectionsView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
