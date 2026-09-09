//
//  SignInWithAppleView.swift
//  CustomFlows
//

import AuthenticationServices
import ClerkKit
import ClerkKitUI
import SwiftUI

struct SignInWithAppleView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var showDocs = false

  var body: some View {
    Form {
      Section {
        Button {
          Task {
            await handleSignUpWithApple()
          }
        } label: {
          HStack {
            Image(systemName: "apple.logo")
            Text("Sign In with Apple")
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .navigationTitle("Sign in with Apple")
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
      if let url = AuthFlow.signInWithApple.documentationURL {
        SafariView(url: url)
      }
    }
  }

  private func handleSignUpWithApple() async {
    do {
      let result = try await clerk.authenticateWithSSO(.init(strategy: .oauthTokenApple, start: .signIn, transferable: true))
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
    SignInWithAppleView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
