//
//  CustomSignInView.swift
//  E2EHost
//

import ClerkKit
import SwiftUI

struct CustomSignInView: View {
  private enum Step {
    case phoneNumber
    case code
  }

  @Environment(Clerk.self) private var clerk

  let onSignedIn: () -> Void

  @State private var step = Step.phoneNumber
  @State private var phoneNumber = ""
  @State private var code = ""
  @State private var error: String?
  @State private var isBusy = false

  var body: some View {
    VStack(spacing: 16) {
      Text("Custom sign-in")
        .font(.title2)

      switch step {
      case .phoneNumber:
        TextField("Phone number", text: $phoneNumber)
          .keyboardType(.phonePad)
          .textContentType(.telephoneNumber)
          .accessibilityIdentifier(E2EIdentifiers.CustomSignIn.phoneNumber)

        Button("Send code") {
          Task { await sendCode() }
        }
        .accessibilityIdentifier(E2EIdentifiers.CustomSignIn.sendCode)
      case .code:
        TextField("SMS code", text: $code)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
          .accessibilityIdentifier(E2EIdentifiers.CustomSignIn.code)

        Button("Verify code") {
          Task { await verifyCode() }
        }
        .accessibilityIdentifier(E2EIdentifiers.CustomSignIn.verifyCode)
      }

      if let error {
        Text(error)
          .foregroundStyle(.red)
          .accessibilityIdentifier(E2EIdentifiers.CustomSignIn.error)
      }
    }
    .textFieldStyle(.roundedBorder)
    .disabled(isBusy)
    .padding()
  }

  private func sendCode() async {
    await submit {
      try await clerk.auth.signInWithPhoneCode(phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces))
      step = .code
    }
  }

  private func verifyCode() async {
    await submit {
      guard let signIn = clerk.auth.currentSignIn else {
        error = "No sign-in is in progress."
        return
      }

      let verified = try await signIn.verifyCode(code.trimmingCharacters(in: .whitespaces))
      if verified.status == .complete {
        onSignedIn()
      } else {
        error = "Sign-in is \(verified.status.rawValue)."
      }
    }
  }

  private func submit(_ request: () async throws -> Void) async {
    guard !isBusy else {
      return
    }

    isBusy = true
    defer { isBusy = false }
    error = nil

    do {
      try await request()
    } catch {
      self.error = error.localizedDescription
    }
  }
}
