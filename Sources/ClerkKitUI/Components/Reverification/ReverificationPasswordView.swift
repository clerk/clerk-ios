//
//  ReverificationPasswordView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ReverificationPasswordView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(ReverificationFlow.self) private var flow

  let factor: Factor

  @State private var password = ""
  @State private var fieldError: Error?
  @FocusState private var isFocused: Bool

  private var passwordResetReason: ReverificationFlow.PasswordResetReason? {
    ReverificationFlow.PasswordResetReason(fieldError)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Verification required")
          HeaderView(style: .subtitle, text: "Enter your current password to continue")
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          VStack(spacing: 8) {
            ClerkTextField(
              "Enter your password",
              text: $password,
              isSecure: true,
              fieldState: fieldError != nil ? .error : .default,
              accessibilityIdentifier: ClerkAccessibilityIdentifiers.Reverification.password
            )
            .textContentType(ClerkE2EEnvironment.isEnabled ? nil : .password)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .focused($isFocused)
            .onFirstAppear {
              isFocused = true
            }

            if let fieldError {
              ErrorText(error: fieldError, alignment: .leading)
                .font(theme.fonts.subheadline)
                .transition(.blurReplace.animation(.default.speed(2)))
                .id(fieldError.localizedDescription)
            }
          }

          if let passwordResetReason, let resetFactor = flow.resetPasswordFactor {
            Button {
              flow.path.append(.newPassword(resetFactor: resetFactor, reason: passwordResetReason))
            } label: {
              Text("Reset password", bundle: .module)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary())
            .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Reverification.resetPasswordButton)
            .simultaneousGesture(TapGesture())
          } else {
            AsyncButton {
              await submit()
            } label: { isRunning in
              ContinueButtonLabelView(isActive: isRunning)
            }
            .buttonStyle(.primary())
            .disabled(password.isEmpty)
            .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Reverification.continueButton)
            .simultaneousGesture(TapGesture())
          }

          ReverificationUseAnotherMethodButton(factor: factor, stage: .firstFactor)
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
      $1 != nil
    }
    .onChange(of: password) {
      if passwordResetReason != nil {
        fieldError = nil
      }
    }
  }

  private func submit() async {
    guard let session = flow.session else { return }
    isFocused = false

    do {
      let verification = try await session.verifyWithPassword(password)
      fieldError = nil
      await flow.handle(verification)
    } catch {
      guard !error.isCancellationError else { return }
      fieldError = error
    }
  }
}

#Preview {
  ReverificationPasswordView(factor: .mockPassword)
    .environment(ReverificationFlow(level: .firstFactor))
    .clerkPreview()
}

#endif
