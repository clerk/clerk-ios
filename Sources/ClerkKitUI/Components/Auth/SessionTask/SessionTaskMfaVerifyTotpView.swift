//
//  SessionTaskMfaVerifyTotpView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaVerifyTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = VerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var showConfirmation = false

  @FocusState private var otpFieldIsFocused: Bool

  let onDone: () -> Void

  enum VerificationState {
    case `default`
    case verifying
    case success
    case error(Error)
  }

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

        verificationStatusView
          .padding(.bottom, 32)

        SecuredByClerkView()
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(16)
    }
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
    .navigationDestination(isPresented: $showConfirmation) {
      SessionTaskMfaTotpConfirmationView(onDone: onDone)
    }
  }

  private var verificationStatusView: some View {
    Group {
      switch verificationState {
      case .verifying:
        HStack(spacing: 4) {
          SpinnerView()
            .frame(width: 16, height: 16)
          Text("Verifying...", bundle: .module)
        }
        .foregroundStyle(theme.colors.mutedForeground)
      case .success:
        HStack(spacing: 4) {
          Image("icon-check-circle", bundle: .module)
            .foregroundStyle(theme.colors.success)
          Text("Success", bundle: .module)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      case let .error(error):
        ErrorText(error: error)
      default:
        EmptyView()
      }
    }
    .font(theme.fonts.subheadline)
  }

  private func attempt() async {
    guard let user = clerk.user else { return }
    verificationState = .verifying

    do {
      _ = try await user.verifyTOTP(code: code)
      verificationState = .success
      showConfirmation = true
    } catch {
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }
    }
  }
}

#endif
