//
//  ReverificationBackupCodeView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ReverificationBackupCodeView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(ReverificationFlow.self) private var flow

  let factor: Factor

  @State private var code = ""
  @State private var fieldError: Error?
  @FocusState private var isFocused: Bool

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Enter a backup code")
          HeaderView(style: .subtitle, text: "Your backup code is the one you got when setting up two-step verification.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          VStack(spacing: 8) {
            ClerkTextField(
              "Backup code",
              text: $code,
              fieldState: fieldError != nil ? .error : .default,
              accessibilityIdentifier: ClerkAccessibilityIdentifiers.Reverification.backupCode
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled()
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

          AsyncButton {
            await submit()
          } label: { isRunning in
            ContinueButtonLabelView(isActive: isRunning)
          }
          .buttonStyle(.primary())
          .disabled(code.isEmptyTrimmed)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Reverification.continueButton)
          .simultaneousGesture(TapGesture())

          ReverificationUseAnotherMethodButton(factor: factor, stage: .secondFactor)
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
  }

  private func submit() async {
    guard let session = flow.session else { return }
    isFocused = false

    do {
      let verification = try await session.verifyWithBackupCode(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
      fieldError = nil
      await flow.handle(verification)
    } catch {
      guard !error.isCancellationError else { return }
      fieldError = error
    }
  }
}

#Preview {
  ReverificationBackupCodeView(factor: .mockBackupCode)
    .environment(ReverificationFlow(level: .secondFactor))
    .clerkPreview()
}

#endif
