//
//  EmailPasswordView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
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
  @Environment(CustomFlowFeedback.self) private var feedback
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
      try await clerk.signIn.password(.case1(.init(password: password, identifier: emailAddress)))
      if clerk.signIn.status == .complete {
        try await clerk.signIn.finalize()
      } else {
        feedback.continuation = .signIn
      }
    } catch {
      feedback.error = error.localizedDescription
    }
  }
}

struct EmailPasswordSignUpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
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
      let signUp = clerk.signUp
      try await signUp.create(.init(
        emailAddress: emailAddress,
        password: password
      ))
      try await signUp.verifications.sendEmailCode()
      isVerifying = true
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verify(code: String) async {
    do {
      let signUp = clerk.signUp
      try await signUp.verifications.verifyEmailCode(.init(code: code))

      switch signUp.status {
      case .complete:
        try await signUp.finalize()
      default:
        feedback.continuation = .signUp
      }
    } catch {
      feedback.error = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    EmailPasswordView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
