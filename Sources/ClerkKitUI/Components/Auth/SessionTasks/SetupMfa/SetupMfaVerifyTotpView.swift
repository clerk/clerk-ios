//
//  SetupMfaVerifyTotpView.swift
//  Clerk
//
//  Created by Clerk on 1/29/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SetupMfaVerifyTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var code = ""
  @State private var error: Error?
  @State private var isVerifying = false
  @State private var fieldState: OTPField.FieldState = .default
  @FocusState private var isFocused: Bool

  let totp: TOTPResource

  var session: Session? {
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var user: User? {
    session?.user
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Verify authenticator code")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "Enter the verification code from your authenticator application")
          .padding(.bottom, 32)

        VStack(spacing: 4) {
          OTPField(
            code: $code,
            fieldState: $fieldState,
            isFocused: $isFocused
          ) { _ in
            await verifyCode()
          }
          .onFirstAppear {
            isFocused = true
          }

          if let error {
            ErrorText(error: error, alignment: .leading)
              .font(theme.fonts.subheadline)
              .transition(.blurReplace.animation(.default))
              .id(error.localizedDescription)
          }
        }
        .padding(.bottom, 24)

        AsyncButton {
          await verifyCode()
        } label: { isRunning in
          HStack(spacing: 4) {
            Text("Continue", bundle: .module)
            Image("icon-triangle-right", bundle: .module)
              .foregroundStyle(theme.colors.primaryForeground)
              .opacity(0.6)
          }
          .frame(maxWidth: .infinity)
          .overlayProgressView(isActive: isRunning) {
            SpinnerView(color: theme.colors.primaryForeground)
          }
        }
        .buttonStyle(.primary())
        .disabled(code.count != 6)
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          navigation.path.removeLast()
        } label: {
          Image("icon-caret-left", bundle: .module)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
  }

  func verifyCode() async {
    error = nil
    fieldState = .default
    isFocused = false
    isVerifying = true
    defer { isVerifying = false }

    guard let user else { return }

    do {
      let verifiedTotp = try await user.verifyTOTP(code: code)
      if let backupCodes = verifiedTotp.backupCodes {
        navigation.path.append(AuthView.Destination.setupMfaTotpBackupCodes(backupCodes))
      } else {
        navigation.path.append(AuthView.Destination.setupMfaTotpSuccess)
      }
    } catch {
      self.error = error
      fieldState = .error
    }
  }
}

#Preview {
  SetupMfaVerifyTotpView(totp: .mock)
    .environment(\.clerkTheme, .clerk)
}

#endif
