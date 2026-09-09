//
//  EnterpriseConnectionsView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct EnterpriseConnectionsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
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
      let result = try await clerk.authenticateWithSSO(.init(strategy: .enterpriseSso, identifier: emailAddress, start: .signIn, transferable: true))
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
    EnterpriseConnectionsView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
