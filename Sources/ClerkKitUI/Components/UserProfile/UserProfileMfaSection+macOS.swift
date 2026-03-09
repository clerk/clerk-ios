//
//  UserProfileMfaSection+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileMfaSection: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var isAddTotpPresented = false
  @State private var backupCodesResource: BackupCodeResource?
  @State private var isRemovingTotp = false
  @State private var isRegeneratingBackupCodes = false
  @State private var errorMessage: String?

  private var user: User? {
    clerk.user
  }

  private var totpEnabled: Bool {
    user?.totpEnabled == true
  }

  private var backupCodesEnabled: Bool {
    user?.backupCodeEnabled == true
  }

  private var canAddAuthenticatorApp: Bool {
    clerk.environment?.userSettings.attributes["authenticator_app"]?.enabled == true && !totpEnabled
  }

  var body: some View {
    GroupBox("Two-Step Verification") {
      VStack(alignment: .leading, spacing: 16) {
        if totpEnabled {
          VStack(alignment: .leading, spacing: 8) {
            Text("Authenticator app")
              .font(theme.fonts.subheadline.weight(.medium))
              .foregroundStyle(theme.colors.foreground)

            Text("Two-step verification is currently enabled with an authenticator app.")
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)
              .fixedSize(horizontal: false, vertical: true)

            HStack {
              Spacer()

              Button("Remove") {
                Task {
                  await disableTotp()
                }
              }
              .buttonStyle(.negative(config: .init(emphasis: .low, size: .small)))
              .disabled(isRemovingTotp)
            }
          }
        } else {
          Text("No two-step verification methods are currently configured.")
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)
        }

        if backupCodesEnabled {
          VStack(alignment: .leading, spacing: 8) {
            Text("Backup codes")
              .font(theme.fonts.subheadline.weight(.medium))
              .foregroundStyle(theme.colors.foreground)

            Text("Backup codes are enabled for this account.")
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)

            HStack {
              Button("View / Regenerate") {
                Task {
                  await regenerateBackupCodes()
                }
              }
              .buttonStyle(.secondary(config: .init(emphasis: .low, size: .small)))
              .disabled(isRegeneratingBackupCodes)

              Spacer()
            }
          }
        }

        if canAddAuthenticatorApp {
          HStack {
            Spacer()

            Button("Add Authenticator App") {
              isAddTotpPresented = true
            }
            .buttonStyle(.secondary(config: .init(emphasis: .low)))
          }
        }

        if let errorMessage {
          Text(errorMessage)
            .font(theme.fonts.footnote)
            .foregroundStyle(theme.colors.danger)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .sheet(isPresented: $isAddTotpPresented) {
      UserProfileMfaAddTotpView()
    }
    .sheet(item: $backupCodesResource) { backupCodes in
      BackupCodesView(backupCodes: backupCodes.codes, mfaType: .backupCodes)
    }
  }
}

extension UserProfileMfaSection {
  @MainActor
  private func disableTotp() async {
    guard let user else { return }

    isRemovingTotp = true
    errorMessage = nil
    defer { isRemovingTotp = false }

    do {
      try await user.disableTOTP()
      _ = try? await clerk.refreshClient()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to disable TOTP", error: error)
    }
  }

  @MainActor
  private func regenerateBackupCodes() async {
    guard let user else { return }

    isRegeneratingBackupCodes = true
    errorMessage = nil
    defer { isRegeneratingBackupCodes = false }

    do {
      backupCodesResource = try await user.createBackupCodes()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to regenerate backup codes", error: error)
    }
  }
}

#Preview {
  UserProfileMfaSection()
    .environment(Clerk.preview())
}

#endif
