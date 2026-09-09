//
//  PhoneSMSOTPView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct PhoneSMSOTPView: View {
  @State private var isSignUp = false
  @State private var showDocs = false

  var body: some View {
    Form {
      if isSignUp {
        PhoneSMSOTPSignUpView()
      } else {
        PhoneSMSOTPSignInView()
      }

      Section {
        Button {
          isSignUp.toggle()
        } label: {
          Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
        }
      }
    }
    .navigationTitle("Phone SMS OTP")
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
      if let url = AuthFlow.phoneSMSOTP.documentationURL {
        SafariView(url: url)
      }
    }
  }
}

struct PhoneSMSOTPSignInView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var phoneNumber = ""
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
        TextField("Enter phone number", text: $phoneNumber)
          .textContentType(.telephoneNumber)
          .keyboardType(.phonePad)
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
      try await clerk.signIn.phoneCode.sendCode(.case1(.init(phoneNumber: phoneNumber)))
      isVerifying = true
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verify(code: String) async {
    do {
      let signIn = clerk.signIn
      try await signIn.phoneCode.verifyCode(.init(code: code))

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

struct PhoneSMSOTPSignUpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var phoneNumber = ""
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
        TextField("Enter phone number", text: $phoneNumber)
          .textContentType(.telephoneNumber)
          .keyboardType(.phonePad)
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
      try await signUp.create(.init(phoneNumber: phoneNumber))
      try await signUp.verifications.sendPhoneCode()
      isVerifying = true
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verify(code: String) async {
    do {
      let signUp = clerk.signUp
      try await signUp.verifications.verifyPhoneCode(.init(code: code))

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
    PhoneSMSOTPView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
