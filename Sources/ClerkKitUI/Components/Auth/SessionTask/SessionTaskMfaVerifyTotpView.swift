//
//  SessionTaskMfaVerifyTotpView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaVerifyTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AuthNavigation.self) private var navigation
  @Environment(\.clerkTheme) private var theme

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = CodeVerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var backupCodes = [String]()

  @FocusState private var otpFieldIsFocused: Bool

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        SessionTaskHeaderSection(
          title: "Add authenticator application",
          subtitle: "Enter the verification code from authenticator application"
        )
        .padding(.bottom, 24)

        OTPField(
          code: $code,
          fieldState: $otpFieldState,
          isFocused: $otpFieldIsFocused
        ) { _ in
          await attempt()
        }
        .onAppear {
          verificationState = .default
          otpFieldIsFocused = true
        }
        .padding(.bottom, 24)

        CodeVerificationStatusView(state: verificationState)
          .padding(.bottom, 32)

        SecuredByClerkView()
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(16)
    }
    .clerkErrorPresenting(
      $error,
      action: { error in
        if let clerkApiError = error as? ClerkAPIError, clerkApiError.code == "verification_already_verified" {
          return .init(text: "Continue") {
            verificationState = .verifying
            handleSuccessfulVerification()
          }
        }
        return nil
      }
    )
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
  }

  private func attempt() async {
    guard let user = clerk.user else { return }
    verificationState = .verifying

    do {
      let totp = try await user.verifyTOTP(code: code)
      backupCodes = totp.backupCodes ?? []
      handleSuccessfulVerification()
    } catch {
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }
    }
  }

  private func handleSuccessfulVerification() {
    verificationState = .success
    if !backupCodes.isEmpty {
      navigation.path.append(.backupCodes(backupCodes: backupCodes, mfaType: .authenticatorApp))
    } else {
      navigation.handleSessionTaskCompletion(session: clerk.session, completedTask: .setupMfa)
    }
  }
}

#endif
