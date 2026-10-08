//
//  UserProfileAddMfaView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileAddMfaView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(UserProfileSheetNavigation.self) private var navigation

  @State private var error: Error?
  @State private var navigationInset: CGFloat?

  enum PresentedView: Identifiable, Hashable {
    case sms
    case authApp(TOTPResource)
    case backupCodes([String])

    var id: Self {
      self
    }

    @MainActor
    @ViewBuilder
    var view: some View {
      switch self {
      case .sms:
        UserProfileMfaAddSmsView()
      case let .authApp(totp):
        UserProfileMfaAddTotpView(totp: totp)
      case let .backupCodes(backupCodes):
        NavigationStack {
          BackupCodesView(backupCodes: backupCodes)
        }
      }
    }
  }

  private var environment: Clerk.Environment? {
    clerk.environment
  }

  private var user: User? {
    clerk.user
  }

  private var availableMethods: [Clerk.Environment.MfaMethod] {
    guard let environment, let user else { return [] }
    return environment.mfaMethodsAvailableToAdd(for: user)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Text("Choose how you'd like to receive your two-step verification code.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)

          VStack(spacing: 0) {
            Group {
              if availableMethods.contains(.phoneCode) {
                Button {
                  navigation.chooseMfaTypeIsPresented = false
                  navigation.presentedAddMfaType = .sms
                } label: {
                  UserProfileRowView(icon: "icon-phone", text: "SMS code")
                }
                .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.Mfa.smsCode)
              }

              if availableMethods.contains(.authenticatorApp) {
                AsyncButton {
                  await createTotp()
                } label: { isRunning in
                  UserProfileRowView(icon: "icon-key", text: "Authenticator application")
                    .overlayProgressView(isActive: isRunning)
                }
                .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.Mfa.authenticatorApp)
              }

              if availableMethods.contains(.backupCodes) {
                AsyncButton {
                  await createBackupCodes()
                } label: { isRunning in
                  UserProfileRowView(icon: "icon-lock", text: "Backup codes")
                    .overlayProgressView(isActive: isRunning)
                }
                .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.Mfa.backupCodes)
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
        }
        .padding(.top, 24)
        .clerkErrorPresenting($error)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .preGlassSolidNavBar()
        .preGlassDetentSheetBackground()
        .toolbar {
          CancelToolbarItem {
            dismiss()
          }

          ToolbarItem(placement: .principal) {
            Text("Add two-step verification", bundle: .module)
              .font(theme.fonts.headline)
              .foregroundStyle(theme.colors.foreground)
          }
        }
        .contentSizedSheet(additionalHeight: navigationInset)
      }
      #if os(macOS)
      .frame(minWidth: 460, maxWidth: 620)
      #endif
      .scrollBounceBehavior(.basedOnSize)
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.safeAreaInsets.top
      } action: { navigationInset = $0 }
    }
  }
}

extension UserProfileAddMfaView {
  private func createTotp() async {
    guard let user else { return }

    do {
      let totp = try await user.createTOTP()
      navigation.chooseMfaTypeIsPresented = false
      navigation.presentedAddMfaType = .authApp(totp)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to create TOTP", error: error)
    }
  }

  private func createBackupCodes() async {
    guard let user else { return }

    do {
      let backupCodes = try await user.createBackupCodes()
      navigation.chooseMfaTypeIsPresented = false
      navigation.presentedAddMfaType = .backupCodes(backupCodes.codes)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to create backup codes", error: error)
    }
  }
}

#Preview {
  UserProfileAddMfaView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
