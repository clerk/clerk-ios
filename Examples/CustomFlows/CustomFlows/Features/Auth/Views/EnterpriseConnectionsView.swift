//
//  EnterpriseConnectionsView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct EnterpriseConnectionsView: View {
  @Environment(Clerk.self) private var clerk
  @State private var emailAddress = ""
  @State private var showDocs = false

  var body: some View {
    Form {
      Section {
        TextField("Enter email address", text: $emailAddress)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .autocapitalization(.none)
          .autocorrectionDisabled()
      }

      Section {
        Button("Sign In with Enterprise SSO") {
          Task {
            await handleSignIn()
          }
        }
      }
    }
    .navigationTitle("Enterprise Connections")
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
      if let url = AuthFlow.enterpriseConnections.documentationURL {
        SafariView(url: url)
      }
    }
  }

  private func handleSignIn() async {
    do {
      let result = try await clerk.auth.signInWithEnterpriseSSO(emailAddress: emailAddress)
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
    EnterpriseConnectionsView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
