//
//  SessionTaskMfaView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A full-screen MFA enrollment flow shown when a session requires forced MFA setup.
///
/// This view is presented after sign-in/sign-up completes when the backend requires
/// the user to enroll in at least one MFA method before the session can become active.
struct SessionTaskMfaView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var showSmsChooseNumber = false
  @State private var showSmsAddPhone = false
  @State private var showTotpSetup = false
  @State private var totpResource: TOTPResource?
  @State private var error: Error?

  enum BackupCodesMfaType {
    case phoneCode
    case authenticatorApp
  }

  private var environment: Clerk.Environment? {
    clerk.environment
  }

  private var user: User? {
    clerk.user
  }

  private var phoneCodeIsEnabled: Bool {
    environment?.mfaPhoneCodeIsEnabled == true
  }

  private var authenticatorAppIsEnabled: Bool {
    environment?.mfaAuthenticatorAppIsEnabled == true && user?.totpEnabled != true
  }

  private var noMethodsAvailable: Bool {
    !phoneCodeIsEnabled && !authenticatorAppIsEnabled
  }

  private var hasAvailablePhoneNumbers: Bool {
    let phoneNumbers = (user?.phoneNumbersAvailableForMfa ?? [])
      .filter { $0.verification?.status == .verified }
    return !phoneNumbers.isEmpty
  }

  var body: some View {
    if noMethodsAvailable {
      GetHelpView(context: .signIn)
        .navigationBarBackButtonHidden()
    } else {
      chooseMethodView
        .navigationBarBackButtonHidden()
    }
  }

  // MARK: - Choose Method

  private var chooseMethodView: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Set up two-step verification")
          HeaderView(style: .subtitle, text: "Choose which method you prefer to protect your account with an extra layer of security")
        }
        .padding(.bottom, 32)

        VStack(spacing: 16) {
          if phoneCodeIsEnabled {
            Button {
              if hasAvailablePhoneNumbers {
                showSmsChooseNumber = true
              } else {
                showSmsAddPhone = true
              }
            } label: {
              StrategyOptionButton(iconName: "icon-phone", text: "SMS code")
            }
            .buttonStyle(.secondary())
          }

          if authenticatorAppIsEnabled {
            AsyncButton {
              await createTotp()
            } label: { isRunning in
              StrategyOptionButton(iconName: "icon-key", text: "Authenticator application")
                .overlayProgressView(isActive: isRunning)
            }
            .buttonStyle(.secondary())
          }
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
    .clerkErrorPresenting($error)
    .navigationDestination(isPresented: $showSmsChooseNumber) {
      SessionTaskMfaSmsChooseNumberView {
        navigation.sessionTaskComplete = true
      }
    }
    .navigationDestination(isPresented: $showSmsAddPhone) {
      SessionTaskMfaAddPhoneView {
        navigation.sessionTaskComplete = true
      }
    }
    .navigationDestination(isPresented: $showTotpSetup) {
      if let totpResource {
        SessionTaskMfaTotpView(totp: totpResource) {
          navigation.sessionTaskComplete = true
        }
      }
    }
  }

  private func createTotp() async {
    guard let user else { return }

    do {
      let totp = try await user.createTOTP()
      totpResource = totp
      showTotpSetup = true
    } catch {
      self.error = error
      ClerkLogger.error("Failed to create TOTP", error: error)
    }
  }
}

// MARK: - TOTP Setup

private struct SessionTaskMfaTotpView: View {
  @Environment(\.clerkTheme) private var theme

  @State private var showVerify = false

  let totp: TOTPResource
  let onDone: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Badge(key: "Two-step verification setup", style: .secondary)
          .padding(.bottom, 16)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Add authenticator application")
          HeaderView(style: .subtitle, text: "Set up a new sign-in method in your authenticator app and scan the following QR code to link it to your account.")
        }
        .padding(.bottom, 32)

        if let secret = totp.secret {
          VStack(spacing: 12) {
            VStack(spacing: 6) {
              Text("Manual setup key", bundle: .module)
                .font(theme.fonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)

              Text("Make sure Time-based or One-time passwords is enabled, then finish linking your account.", bundle: .module)
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }

            copyableText(secret)

            Button {
              UIPasteboard.general.string = secret
            } label: {
              HStack(spacing: 6) {
                Image("icon-clipboard", bundle: .module)
                  .foregroundStyle(theme.colors.mutedForeground)
                Text("Copy to clipboard", bundle: .module)
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
          }
          .padding(.bottom, 32)
        }

        Button {
          showVerify = true
        } label: {
          HStack(spacing: 4) {
            Text("Continue", bundle: .module)
            Image("icon-triangle-right", bundle: .module)
              .foregroundStyle(theme.colors.primaryForeground)
              .opacity(0.6)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .navigationDestination(isPresented: $showVerify) {
      SessionTaskMfaVerifyTotpView(onDone: onDone)
    }
  }

  private func copyableText(_ string: String) -> some View {
    Text(verbatim: string)
      .font(theme.fonts.subheadline)
      .foregroundStyle(theme.colors.foreground)
      .frame(maxWidth: .infinity, minHeight: 20)
      .lineLimit(1)
      .padding(.vertical, 18)
      .padding(.horizontal, 16)
      .background(theme.colors.muted)
      .clipShape(.rect(cornerRadius: theme.design.borderRadius))
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.inputBorder, lineWidth: 1)
      }
  }
}

// MARK: - TOTP Verification

private struct SessionTaskMfaVerifyTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = VerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var backupCodes: [String]?
  @State private var showBackupCodes = false

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
      VStack(spacing: 24) {
        Text("Enter the verification code from your authenticator application.", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)

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
      .padding(24)
    }
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Verify authenticator app", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .navigationDestination(isPresented: $showBackupCodes) {
      if let backupCodes {
        SessionTaskBackupCodesView(backupCodes: backupCodes, mfaType: .authenticatorApp) {
          onDone()
        }
      }
    }
  }

  private func attempt() async {
    guard let user = clerk.user else { return }
    verificationState = .verifying

    do {
      let totp = try await user.verifyTOTP(code: code)
      verificationState = .success
      backupCodes = totp.backupCodes ?? []
      showBackupCodes = true
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

// MARK: - SMS Choose Number

private struct SessionTaskMfaSmsChooseNumberView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var phoneNumberToVerify: ClerkKit.PhoneNumber?
  @State private var showVerifySms = false
  @State private var showAddPhone = false
  @State private var error: Error?

  let onDone: () -> Void

  private var user: User? {
    clerk.user
  }

  private var availablePhoneNumbers: [ClerkKit.PhoneNumber] {
    (user?.phoneNumbersAvailableForMfa ?? [])
      .filter { $0.verification?.status == .verified }
      .sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Badge(key: "Two-step verification setup", style: .secondary)
          .padding(.bottom, 16)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Add SMS code verification")
          HeaderView(style: .subtitle, text: "Choose the phone number you want to use for SMS code two-step verification")
        }
        .padding(.bottom, 32)

        VStack(spacing: 12) {
          ForEach(availablePhoneNumbers) { phoneNumber in
            AsyncButton {
              await sendCode(to: phoneNumber)
            } label: { isRunning in
              AddMfaSmsRow(
                phoneNumber: phoneNumber,
                isSelected: false
              )
              .overlayProgressView(isActive: isRunning)
            }
            .buttonStyle(.pressedBackground)
          }
        }
        .padding(.bottom, 24)

        Button {
          showAddPhone = true
        } label: {
          Text("Add phone number", bundle: .module)
        }
        .buttonStyle(
          .primary(
            config: .init(
              emphasis: .none,
              size: .small
            )
          )
        )
        .padding(.bottom, 32)

        SecuredByClerkView()
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
    .navigationDestination(isPresented: $showAddPhone) {
      SessionTaskMfaAddPhoneView(onDone: onDone)
    }
    .navigationDestination(isPresented: $showVerifySms) {
      if let phoneNumberToVerify {
        SessionTaskMfaVerifySmsView(
          phoneNumber: phoneNumberToVerify,
          onDone: onDone
        )
      }
    }
  }

  private func sendCode(to phoneNumber: ClerkKit.PhoneNumber) async {
    do {
      try await phoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: phoneNumber.phoneNumber)
      phoneNumberToVerify = phoneNumber
      showVerifySms = true
    } catch {
      self.error = error
      ClerkLogger.error("Failed to send SMS code", error: error)
    }
  }
}

// MARK: - SMS Add Phone

private struct SessionTaskMfaAddPhoneView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var phoneNumber = ""
  @State private var phoneNumberToVerify: ClerkKit.PhoneNumber?
  @State private var showVerifySms = false
  @State private var error: Error?

  @FocusState private var isFocused: Bool

  let onDone: () -> Void

  private var user: User? {
    clerk.user
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Badge(key: "Two-step verification setup", style: .secondary)
          .padding(.bottom, 16)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Add phone number")
          HeaderView(style: .subtitle, text: "A text message containing a verification code will be sent to this phone number. Message and data rates may apply.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          VStack(spacing: 4) {
            ClerkPhoneNumberField("Enter your phone number", text: $phoneNumber)
              .textContentType(.telephoneNumber)
              .keyboardType(.numberPad)
              .focused($isFocused)
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

          AsyncButton {
            await addPhoneNumber()
          } label: { isRunning in
            HStack {
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
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
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
    .navigationDestination(isPresented: $showVerifySms) {
      if let phoneNumberToVerify {
        SessionTaskMfaVerifySmsView(
          phoneNumber: phoneNumberToVerify,
          onDone: onDone
        )
      }
    }
  }

  private func addPhoneNumber() async {
    guard let user else { return }

    do {
      let newPhoneNumber = try await user.createPhoneNumber(phoneNumber)
      try await newPhoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: newPhoneNumber.phoneNumber)
      phoneNumberToVerify = newPhoneNumber
      showVerifySms = true
    } catch {
      self.error = error
      ClerkLogger.error("Failed to add phone number", error: error)
    }
  }
}

// MARK: - SMS Verification

private struct SessionTaskMfaVerifySmsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(CodeLimiter.self) private var codeLimiter

  @State private var code = ""
  @State private var error: Error?
  @State private var verificationState = VerificationState.default
  @State private var otpFieldState = OTPField.FieldState.default
  @State private var backupCodes: [String]?
  @State private var showBackupCodes = false

  @FocusState private var otpFieldIsFocused: Bool

  let phoneNumber: ClerkKit.PhoneNumber
  let onDone: () -> Void

  enum VerificationState {
    case `default`
    case verifying
    case success
    case error(Error)
  }

  private var codeLimiterIdentifier: String {
    phoneNumber.phoneNumber
  }

  private var remainingSeconds: Int {
    codeLimiter.remainingCooldown(for: codeLimiterIdentifier)
  }

  private var resendString: LocalizedStringKey {
    if remainingSeconds > 0 {
      "Resend (\(remainingSeconds))"
    } else {
      "Resend"
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Badge(key: "Two-step verification setup", style: .secondary)
          .padding(.bottom, 16)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Verify your phone number")
          HeaderView(style: .subtitle, text: "A text message containing a verification code will be sent to this phone number. Message and data rates may apply.")
        }
        .padding(.bottom, 16)

        Button {
          dismiss()
        } label: {
          IdentityPreviewView(label: phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
        }
        .buttonStyle(.secondary(config: .init(size: .small)))
        .simultaneousGesture(TapGesture())
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
        .padding(.bottom, 16)

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
        .padding(.bottom, 16)

        AsyncButton {
          await resend()
        } label: { isRunning in
          HStack(spacing: 2) {
            Text("Didn't receive a code?", bundle: .module)
            Text(resendString, bundle: .module)
              .foregroundStyle(
                remainingSeconds > 0
                  ? theme.colors.mutedForeground
                  : theme.colors.primary
              )
              .monospacedDigit()
              .contentTransition(.numericText(countsDown: true))
              .animation(.default, value: remainingSeconds)
          }
          .overlayProgressView(isActive: isRunning)
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(
          .secondary(
            config: .init(
              emphasis: .none,
              size: .small
            )
          )
        )
        .disabled(remainingSeconds > 0)
        .simultaneousGesture(TapGesture())
        .padding(.bottom, 32)

        SecuredByClerkView()
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
    .navigationDestination(isPresented: $showBackupCodes) {
      if let backupCodes {
        SessionTaskBackupCodesView(backupCodes: backupCodes, mfaType: .phoneCode) {
          onDone()
        }
      }
    }
  }

  private func attempt() async {
    verificationState = .verifying

    do {
      try await phoneNumber.verifyCode(code)
      let reserved = try await phoneNumber.setReservedForSecondFactor()
      codeLimiter.clearRecord(for: codeLimiterIdentifier)
      verificationState = .success
      backupCodes = reserved.backupCodes ?? []
      showBackupCodes = true
    } catch {
      otpFieldState = .error
      verificationState = .error(error)

      if let clerkError = error as? ClerkAPIError, clerkError.meta?["param_name"] == nil {
        self.error = clerkError
        otpFieldIsFocused = false
      }
    }
  }

  private func resend() async {
    code = ""
    verificationState = .default

    do {
      try await phoneNumber.sendCode()
      codeLimiter.recordCodeSent(for: codeLimiterIdentifier)
    } catch {
      otpFieldIsFocused = false
      self.error = error
      ClerkLogger.error("Failed to resend SMS code", error: error)
    }
  }
}

// MARK: - Backup Codes

private struct SessionTaskBackupCodesView: View {
  @Environment(\.clerkTheme) private var theme

  let backupCodes: [String]
  let mfaType: SessionTaskMfaView.BackupCodesMfaType
  let onDone: () -> Void

  private var title: LocalizedStringKey {
    switch mfaType {
    case .phoneCode:
      "SMS code verification enabled"
    case .authenticatorApp:
      "Authenticator app verification enabled"
    }
  }

  private var subtitle: LocalizedStringKey {
    switch mfaType {
    case .phoneCode:
      "When you sign in, you'll be asked for a verification code sent to this phone number."
    case .authenticatorApp:
      "When you sign in, you'll need to enter a verification code from this authenticator app."
    }
  }

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Badge(key: "Two-step verification setup", style: .secondary)
          .padding(.bottom, 16)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: title)
          HeaderView(style: .subtitle, text: subtitle)
        }
        .padding(.bottom, 32)

        // Backup codes card
        VStack(spacing: 0) {
          VStack(spacing: 6) {
            Text("Backup codes", bundle: .module)
              .font(theme.fonts.subheadline)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.foreground)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text("Save these codes somewhere safe. If you lose access to your authentication device, you can use a backup code to sign in.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(16)

          Divider()

          LazyVGrid(columns: columns, spacing: 16) {
            ForEach(backupCodes, id: \.self) { code in
              Text(code)
                .font(theme.fonts.footnote)
                .foregroundStyle(theme.colors.foreground)
            }
          }
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(theme.colors.muted)

          Divider()

          HStack(spacing: 16) {
            ShareLink(item: backupCodes.joined(separator: "\n")) {
              Text("Download", bundle: .module)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())

            Button {
              UIPasteboard.general.string = backupCodes.joined(separator: ", ")
            } label: {
              Text("Copy to clipboard", bundle: .module)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
          }
          .padding(16)
        }
        .background(theme.colors.input)
        .clipShape(.rect(cornerRadius: theme.design.borderRadius))
        .overlay {
          RoundedRectangle(cornerRadius: theme.design.borderRadius)
            .strokeBorder(theme.colors.inputBorder, lineWidth: 1)
        }
        .padding(.bottom, 32)

        Button {
          onDone()
        } label: {
          HStack {
            Text("Continue", bundle: .module)
            Image("icon-triangle-right", bundle: .module)
              .foregroundStyle(theme.colors.primaryForeground)
              .opacity(0.6)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
  }
}

#Preview("Choose Method") {
  SessionTaskMfaView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
