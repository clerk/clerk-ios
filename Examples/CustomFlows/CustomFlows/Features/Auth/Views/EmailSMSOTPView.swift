//
//  EmailSMSOTPView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct EmailPhoneOTPView: View {
  @State private var isSignUp = false

  var body: some View {
    Form {
      if isSignUp {
        EmailPhoneOTPSignUpView()
      } else {
        EmailPhoneOTPSignInView()
      }

      Section {
        Button {
          isSignUp.toggle()
        } label: {
          Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
        }
      }
    }
    .navigationTitle("Email & Phone OTP")
  }
}

struct EmailPhoneOTPSignInView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var emailAddress = ""
  @State private var phoneNumber = ""
  @State private var code = ""
  @State private var isVerifying = false
  @State private var useEmail = true

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
        Picker("Method", selection: $useEmail) {
          Text("Email").tag(true)
          Text("Phone").tag(false)
        }

        if useEmail {
          TextField("Enter email address", text: $emailAddress)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled()
        } else {
          TextField("Enter phone number", text: $phoneNumber)
            .textContentType(.telephoneNumber)
            .keyboardType(.phonePad)
        }
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
      if useEmail {
        try await clerk.signIn.emailCode.sendCode(.case1(.init(emailAddress: emailAddress)))
      } else {
        try await clerk.signIn.phoneCode.sendCode(.case1(.init(phoneNumber: phoneNumber)))
      }
      isVerifying = true
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verify(code: String) async {
    do {
      let signIn = clerk.signIn
      if useEmail {
        try await signIn.emailCode.verifyCode(.init(code: code))
      } else {
        try await signIn.phoneCode.verifyCode(.init(code: code))
      }

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

struct EmailPhoneOTPSignUpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var emailAddress = ""
  @State private var phoneNumber = ""
  @State private var code = ""
  @State private var isVerifying = false
  @State private var useEmail = true

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
        Picker("Method", selection: $useEmail) {
          Text("Email").tag(true)
          Text("Phone").tag(false)
        }

        if useEmail {
          TextField("Enter email address", text: $emailAddress)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled()
        } else {
          TextField("Enter phone number", text: $phoneNumber)
            .textContentType(.telephoneNumber)
            .keyboardType(.phonePad)
        }
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
      if useEmail {
        try await signUp.create(.init(emailAddress: emailAddress))
        try await signUp.verifications.sendEmailCode()
      } else {
        try await signUp.create(.init(phoneNumber: phoneNumber))
        try await signUp.verifications.sendPhoneCode()
      }
      isVerifying = true
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verify(code: String) async {
    do {
      let signUp = clerk.signUp
      if useEmail {
        try await signUp.verifications.verifyEmailCode(.init(code: code))
      } else {
        try await signUp.verifications.verifyPhoneCode(.init(code: code))
      }

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
    EmailPhoneOTPView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
