//
//  PhoneSMSOTPView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
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
      try await clerk.auth.signInWithPhoneCode(phoneNumber: phoneNumber)
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

struct PhoneSMSOTPSignUpView: View {
  @Environment(Clerk.self) private var clerk
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
      let signUp = try await clerk.auth.signUp(phoneNumber: phoneNumber)
      try await signUp.sendPhoneCode()
      isVerifying = true
    } catch {
      dump(error)
    }
  }

  private func verify(code: String) async {
    do {
      guard var signUp = clerk.auth.currentSignUp else { return }
      signUp = try await signUp.verifyPhoneCode(code)

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
    PhoneSMSOTPView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
