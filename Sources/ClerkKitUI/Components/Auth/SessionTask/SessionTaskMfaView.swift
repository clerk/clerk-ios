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

  @State private var flowStep: FlowStep = .chooseMethod
  @State private var error: Error?

  enum FlowStep {
    case chooseMethod
    case addTotp(TOTPResource)
    case addSms
    case backupCodes([String], mfaType: BackupCodesMfaType)
  }

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

  var body: some View {
    Group {
      switch flowStep {
      case .chooseMethod:
        if noMethodsAvailable {
          GetHelpView(context: .signIn)
        } else {
          chooseMethodView
        }
      case let .addTotp(totp):
        SessionTaskMfaTotpView(totp: totp) { backupCodes in
          if let backupCodes {
            flowStep = .backupCodes(backupCodes, mfaType: .authenticatorApp)
          } else {
            flowStep = .chooseMethod
          }
        } onCancel: {
          flowStep = .chooseMethod
        }
      case .addSms:
        SessionTaskMfaSmsView { backupCodes in
          flowStep = .backupCodes(backupCodes, mfaType: .phoneCode)
        } onCancel: {
          flowStep = .chooseMethod
        }
      case let .backupCodes(codes, mfaType):
        SessionTaskBackupCodesView(backupCodes: codes, mfaType: mfaType) {
          navigation.sessionTaskComplete = true
        }
      }
    }
    .animation(.default, value: flowStepIdentifier)
    .navigationBarBackButtonHidden()
  }

  private var flowStepIdentifier: String {
    switch flowStep {
    case .chooseMethod: "chooseMethod"
    case .addTotp: "addTotp"
    case .addSms: "addSms"
    case .backupCodes: "backupCodes"
    }
  }

  // MARK: - Choose Method

  private var chooseMethodView: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Add two-step verification")
          HeaderView(style: .subtitle, text: "Your account requires additional security. You need to set up two-step verification to continue.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 0) {
          Group {
            if phoneCodeIsEnabled {
              Button {
                flowStep = .addSms
              } label: {
                UserProfileRowView(icon: "icon-phone", text: "SMS code")
              }
            }

            if authenticatorAppIsEnabled {
              AsyncButton {
                await createTotp()
              } label: { isRunning in
                UserProfileRowView(icon: "icon-key", text: "Authenticator application")
                  .overlayProgressView(isActive: isRunning)
              }
            }
          }
          .overlay(alignment: .bottom) {
            Rectangle()
              .frame(height: 1)
              .foregroundStyle(theme.colors.border)
          }
          .buttonStyle(.pressedBackground)
          .simultaneousGesture(TapGesture())
        }
        .overlay(alignment: .top) {
          Rectangle()
            .frame(height: 1)
            .foregroundStyle(theme.colors.border)
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
  }

  private func createTotp() async {
    guard let user else { return }

    do {
      let totp = try await user.createTOTP()
      flowStep = .addTotp(totp)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to create TOTP", error: error)
    }
  }
}

// MARK: - TOTP Setup

private struct SessionTaskMfaTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var showVerify = false

  let totp: TOTPResource
  let onComplete: ([String]?) -> Void
  let onCancel: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        if let secret = totp.secret {
          Text("Set up a new sign-in method in your authenticator and enter the Key provided below.\n\nMake sure Time-based or One-time passwords is enabled, then finish linking your account.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)

          VStack(spacing: 12) {
            copyableText(secret)

            Button {
              copyToClipboard(secret)
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
        }

        if let uri = totp.uri {
          Text("Alternatively, if your authenticator supports TOTP URIs, you can also copy the full URI.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)

          VStack(spacing: 12) {
            copyableText(uri)

            Button {
              copyToClipboard(uri)
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
      }
      .padding(24)
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          onCancel()
        }
        .foregroundStyle(theme.colors.primary)
      }

      ToolbarItem(placement: .principal) {
        Text("Add authenticator application", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .navigationDestination(isPresented: $showVerify) {
      SessionTaskMfaVerifyTotpView(onComplete: onComplete)
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
          .strokeBorder(theme.colors.border, lineWidth: 1)
      }
  }

  private func copyToClipboard(_ text: String) {
    UIPasteboard.general.string = text
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

  @FocusState private var otpFieldIsFocused: Bool

  let onComplete: ([String]?) -> Void

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
  }

  private func attempt() async {
    guard let user = clerk.user else { return }
    verificationState = .verifying

    do {
      let totp = try await user.verifyTOTP(code: code)
      verificationState = .success
      onComplete(totp.backupCodes)
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

// MARK: - SMS Setup

private struct SessionTaskMfaSmsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var selectedPhoneNumber: ClerkKit.PhoneNumber?
  @State private var addPhoneNumberIsPresented = false
  @State private var error: Error?

  let onComplete: ([String]) -> Void
  let onCancel: () -> Void

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
      VStack(spacing: 24) {
        Text("Select an existing phone number to register for SMS code two-step verification or add a new one.", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 12) {
          ForEach(availablePhoneNumbers) { phoneNumber in
            Button {
              selectedPhoneNumber = phoneNumber
            } label: {
              AddMfaSmsRow(
                phoneNumber: phoneNumber,
                isSelected: selectedPhoneNumber == phoneNumber
              )
            }
            .buttonStyle(.pressedBackground)
          }
        }

        AsyncButton {
          guard let selectedPhoneNumber else { return }
          await reserveForSecondFactor(phoneNumber: selectedPhoneNumber)
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
        .disabled(selectedPhoneNumber == nil)

        Button {
          addPhoneNumberIsPresented = true
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
      }
      .padding(24)
    }
    .clerkErrorPresenting($error)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          onCancel()
        }
        .foregroundStyle(theme.colors.primary)
      }

      ToolbarItem(placement: .principal) {
        Text("Add SMS code verification", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .background(theme.colors.background)
    .sensoryFeedback(.selection, trigger: selectedPhoneNumber)
    .sheet(isPresented: $addPhoneNumberIsPresented) {
      UserProfileAddPhoneView()
    }
  }

  private func reserveForSecondFactor(phoneNumber: ClerkKit.PhoneNumber) async {
    do {
      let phoneNumber = try await phoneNumber.setReservedForSecondFactor()
      if let backupCodes = phoneNumber.backupCodes {
        onComplete(backupCodes)
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to reserve phone number for second factor", error: error)
    }
  }
}

// MARK: - Backup Codes

private struct SessionTaskBackupCodesView: View {
  @Environment(\.clerkTheme) private var theme

  let backupCodes: [String]
  let mfaType: SessionTaskMfaView.BackupCodesMfaType
  let onDone: () -> Void

  private var instructions: LocalizedStringKey {
    switch mfaType {
    case .phoneCode:
      "When signing in, you will need to enter a verification code sent to this phone number as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
    case .authenticatorApp:
      "Two-step verification is now enabled. When signing in, you will need to enter a verification code from this authenticator app as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Backup codes")
          HeaderView(style: .subtitle, text: instructions)
        }
        .padding(.bottom, 32)

        BackupCodesGrid(backupCodes: backupCodes)
          .padding(.bottom, 24)

        Button {
          copyToClipboard(backupCodes.joined(separator: ", "))
        } label: {
          HStack(spacing: 6) {
            Image("icon-clipboard", bundle: .module)
              .foregroundStyle(theme.colors.mutedForeground)
            Text("Copy to clipboard", bundle: .module)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondary())
        .padding(.bottom, 24)

        Button {
          onDone()
        } label: {
          Text("Done", bundle: .module)
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

  private func copyToClipboard(_ text: String) {
    UIPasteboard.general.string = text
  }
}

#Preview("Choose Method") {
  SessionTaskMfaView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
