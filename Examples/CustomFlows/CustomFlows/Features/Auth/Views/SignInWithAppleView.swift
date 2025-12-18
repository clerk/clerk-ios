//
//  SignInWithAppleView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import AuthenticationServices
import ClerkKit
import SwiftUI

struct SignInWithAppleView: View {
  @Environment(Clerk.self) private var clerk
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
      try await clerk.auth.signInWithApple()
      dump(clerk.session)
    } catch {
      dump(error)
    }
  }
}

#Preview {
  NavigationStack {
    SignInWithAppleView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
