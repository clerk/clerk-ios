//
//  EmailSMSOTPView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
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
        try await clerk.auth.signInWithEmailCode(emailAddress: emailAddress)
      } else {
        try await clerk.auth.signInWithPhoneCode(phoneNumber: phoneNumber)
      }
      isVerifying = true
    } catch {
      dump(error)
    }
  }

  private func verify(code: String) async {
    do {
      guard var signIn = clerk.auth.currentSignIn else { return }
      signIn = try await signIn.verifyCode(code)

      switch signIn.status {
      case .complete:
        dump(clerk.session)
      default:
        dump(signIn.status)
      }
    } catch {
      dump(error)
    }
  }
}

struct EmailPhoneOTPSignUpView: View {
  @Environment(Clerk.self) private var clerk
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
      let signUp: SignUp
      if useEmail {
        signUp = try await clerk.auth.signUp(emailAddress: emailAddress)
        try await signUp.sendEmailCode()
      } else {
        signUp = try await clerk.auth.signUp(phoneNumber: phoneNumber)
        try await signUp.sendPhoneCode()
      }
      isVerifying = true
    } catch {
      dump(error)
    }
  }

  private func verify(code: String) async {
    do {
      guard var signUp = clerk.auth.currentSignUp else { return }
      if useEmail {
        signUp = try await signUp.verifyEmailCode(code)
      } else {
        signUp = try await signUp.verifyPhoneCode(code)
      }

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
    EmailPhoneOTPView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
