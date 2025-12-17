//
//  EmailPasswordView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct EmailPasswordView: View {
  @State private var isSignUp = false
  @State private var showDocs = false

  var body: some View {
    Form {
      if isSignUp {
        EmailPasswordSignUpView()
      } else {
        EmailPasswordSignInView()
      }

      Section {
        Button {
          isSignUp.toggle()
        } label: {
          Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
        }
      }
    }
    .navigationTitle("Email & Password")
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
      if let url = AuthFlow.emailPassword.documentationURL {
        SafariView(url: url)
      }
    }
  }
}

struct EmailPasswordSignInView: View {
  @Environment(Clerk.self) private var clerk
  @State private var emailAddress = ""
  @State private var password = ""

  var body: some View {
    Section {
      TextField("Enter email address", text: $emailAddress)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .autocapitalization(.none)
        .autocorrectionDisabled()

      SecureField("Enter password", text: $password)
        .textContentType(.password)
    }

    Section {
      Button("Sign In") {
        Task {
          await handleSignIn()
        }
      }
    }
  }

  private func handleSignIn() async {
    do {
      try await clerk.auth.signInWithPassword(identifier: emailAddress, password: password)
    } catch {
      dump(error)
    }
  }
}

struct EmailPasswordSignUpView: View {
  @Environment(Clerk.self) private var clerk
  @State private var emailAddress = ""
  @State private var password = ""
  @State private var code = ""
  @State private var isVerifying = false

  var body: some View {
    if isVerifying {
      Section {
        TextField("Enter your verification code", text: $code)
      }

      Section {
        Button("Verify") {
          Task {
            await verify(code: code)
          }
        }
      }
    } else {
      Section {
        TextField("Enter email address", text: $emailAddress)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .autocapitalization(.none)
          .autocorrectionDisabled()

        SecureField("Enter password", text: $password)
          .textContentType(.newPassword)
      }

      Section {
        Button("Sign Up") {
          Task {
            await handleSignUp()
          }
        }
      }
    }
  }

  private func handleSignUp() async {
    do {
      let signUp = try await clerk.auth.signUp(
        emailAddress: emailAddress,
        password: password
      )
      try await signUp.sendEmailCode()
      isVerifying = true
    } catch {
      dump(error)
    }
  }

  private func verify(code: String) async {
    do {
      guard let inProgressSignUp = clerk.client?.signUp else { return }
      let signUp = try await inProgressSignUp.verifyCode(code, type: .email)

      switch signUp.status {
      case .complete:
        dump(clerk.session)
      default:
        dump(signUp.status)
      }
    } catch {
      dump(error)
    }
  }
}

#Preview {
  NavigationStack {
    EmailPasswordView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
