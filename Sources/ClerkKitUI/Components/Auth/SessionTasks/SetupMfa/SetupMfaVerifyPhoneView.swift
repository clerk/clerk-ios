//
//  SetupMfaVerifyPhoneView.swift
//  Clerk
//
//  Created by Clerk on 1/29/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SetupMfaVerifyPhoneView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(CodeLimiter.self) private var codeLimiter
  @Environment(AuthNavigation.self) private var navigation

  @State private var code = ""
  @State private var error: Error?
  @State private var isVerifying = false
  @State private var fieldState: OTPField.FieldState = .default
  @FocusState private var isFocused: Bool

  let phoneNumber: ClerkKit.PhoneNumber

  var session: Session? {
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var user: User? {
    session?.user
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Verify phone number")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "Enter the verification code sent to \(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)")
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
        .padding(.bottom, 12)

        AsyncButton {
          await resendCode()
        } label: { isRunning in
          HStack(spacing: 2) {
            Text("Didn't receive a code?", bundle: .module)
            Group {
              if codeLimiter.remainingCooldown(for: phoneNumber.phoneNumber) > 0 {
                Text("Resend (\(codeLimiter.remainingCooldown(for: phoneNumber.phoneNumber)))", bundle: .module)
                  .foregroundStyle(theme.colors.mutedForeground)
              } else {
                Text("Resend", bundle: .module)
                  .foregroundStyle(theme.colors.primary)
              }
            }
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .animation(.default, value: codeLimiter.remainingCooldown(for: phoneNumber.phoneNumber))
          }
          .overlayProgressView(isActive: isRunning)
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(codeLimiter.remainingCooldown(for: phoneNumber.phoneNumber) > 0)
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
    .task {
      await sendInitialCode()
    }
  }

  func sendInitialCode() async {
    do {
      _ = try await phoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: phoneNumber.phoneNumber)
    } catch {
      self.error = error
    }
  }

  func resendCode() async {
    error = nil
    code = ""

    do {
      _ = try await phoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: phoneNumber.phoneNumber)
    } catch {
      self.error = error
    }
  }

  func verifyCode() async {
    error = nil
    fieldState = .default
    isFocused = false
    isVerifying = true
    defer { isVerifying = false }

    do {
      _ = try await phoneNumber.verifyCode(code)
      let updatedPhone = try await phoneNumber.setReservedForSecondFactor()
      codeLimiter.clearRecord(for: phoneNumber.phoneNumber)

      if let backupCodes = updatedPhone.backupCodes {
        navigation.path.append(AuthView.Destination.setupMfaPhoneBackupCodes(backupCodes))
      } else {
        navigation.path.append(AuthView.Destination.setupMfaPhoneSuccess)
      }
    } catch {
      self.error = error
      fieldState = .error
    }
  }
}

#Preview {
  SetupMfaVerifyPhoneView(phoneNumber: .mock)
    .environment(\.clerkTheme, .clerk)
}

#endif
