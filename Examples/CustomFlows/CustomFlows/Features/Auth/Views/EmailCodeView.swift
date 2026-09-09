//
//  EmailCodeView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct EmailCodeView: View {
  @State private var isSignUp = false
  @State private var showDocs = false

  var body: some View {
    Form {
      if isSignUp {
        EmailCodeSignUpView()
      } else {
        EmailCodeSignInView()
      }

      Section {
        Button {
          isSignUp.toggle()
        } label: {
          Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
        }
      }
    }
    .navigationTitle("Email Code")
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
      if let url = AuthFlow.emailCode.documentationURL {
        SafariView(url: url)
      }
    }
  }
}

struct EmailCodeSignInView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var emailAddress = ""
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
      }

      Section {
        Button("Sign In") {
          Task {
            await handleSignIn()
          }
        }
      }
    }
  }

  private func handleSignIn() async {
    do {
      try await clerk.signIn.emailCode.sendCode(.case1(.init(emailAddress: emailAddress)))
      isVerifying = true
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verify(code: String) async {
    do {
      let signIn = clerk.signIn
      try await signIn.emailCode.verifyCode(.init(code: code))

      switch signIn.status {
      case .complete:
        try await signIn.finalize()
      default:
        feedback.continuation = .signIn
      }
    } catch {
      feedback.error = error.localizedDescription
    }
  }
}

struct EmailCodeSignUpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var emailAddress = ""
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
      try await signUp.create(.init(emailAddress: emailAddress))
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
    EmailCodeView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
