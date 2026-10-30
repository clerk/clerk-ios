//
//  CustomReverifyView.swift
//  E2EHost
//

import ClerkKit
import SwiftUI

struct CustomReverifyView: View {
  private enum Step {
    case start
    case code
  }

  @Environment(Clerk.self) private var clerk

  let onReverified: () -> Void

  @State private var step = Step.start
  @State private var code = ""
  @State private var newPassword = ""
  @State private var error: String?
  @State private var isBusy = false

  var body: some View {
    VStack(spacing: 16) {
      Text("Custom reverification")
        .font(.title2)

      switch step {
      case .start:
        Button("Send reset code") {
          Task { await sendCode() }
        }
        .accessibilityIdentifier(E2EIdentifiers.CustomReverify.sendCode)
      case .code:
        TextField("Email code", text: $code)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
          .accessibilityIdentifier(E2EIdentifiers.CustomReverify.code)

        SecureField("New password", text: $newPassword)
          .accessibilityIdentifier(E2EIdentifiers.CustomReverify.newPassword)

        Button("Verify and set password") {
          Task { await verifyCode() }
        }
        .accessibilityIdentifier(E2EIdentifiers.CustomReverify.verifyCode)
      }

      if let error {
        Text(error)
          .foregroundStyle(.red)
          .accessibilityIdentifier(E2EIdentifiers.CustomReverify.error)
      }
    }
    .textFieldStyle(.roundedBorder)
    .disabled(isBusy)
    .padding()
  }

  private func sendCode() async {
    await submit {
      guard let session = clerk.session else {
        error = "No session is active."
        return
      }

      let verification = try await session.startVerification(level: .firstFactor)
      guard let emailAddressId = verification.supportedFirstFactors?
        .first(where: { $0.strategy == .resetPasswordEmailCode })?
        .emailAddressId
      else {
        error = "Reverification offers no reset password email code."
        return
      }

      try await session.sendResetPasswordEmailCode(emailAddressId: emailAddressId)
      step = .code
    }
  }

  private func verifyCode() async {
    await submit {
      guard let session = clerk.session else {
        error = "No session is active."
        return
      }

      let verified = try await session.verifyWithResetPasswordEmailCode(
        code: code.trimmingCharacters(in: .whitespaces),
        newPassword: newPassword
      )
      if verified.status == .complete {
        onReverified()
      } else {
        error = "Reverification is \(verified.status.rawValue)."
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
