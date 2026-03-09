//
//  UserProfileSecurityView+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileSecurityView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  @State private var isPasswordSheetPresented = false
  @State private var isDeleteAccountPresented = false

  private var user: User? {
    clerk.user
  }

  private var passwordIsEnabled: Bool {
    clerk.environment?.userSettings.attributes["password"]?.enabled == true
  }

  private var shouldShowDevices: Bool {
    guard let user else { return false }
    return !(clerk.sessionsByUserId[user.id] ?? []).filter { $0.latestActivity != nil }.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Security")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text("Manage password access and review active devices for this account.")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)

      if passwordIsEnabled, let user {
        GroupBox("Password") {
          VStack(alignment: .leading, spacing: 12) {
            Text(user.passwordEnabled ? "A password is currently configured for this account." : "No password is currently configured for this account.")
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)
              .fixedSize(horizontal: false, vertical: true)

            HStack {
              Spacer()

              Button(user.passwordEnabled ? "Change Password" : "Add Password") {
                isPasswordSheetPresented = true
              }
              .buttonStyle(.secondary(config: .init(emphasis: .low)))
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      if clerk.environment?.userSettings.passkeySettings?.allowAutofill != nil {
        UserProfilePasskeySection()
      }

      if clerk.environment?.userSettings.attributes["authenticator_app"]?.enabled == true ||
        user?.totpEnabled == true ||
        user?.backupCodeEnabled == true
      {
        UserProfileMfaSection()
      }

      if shouldShowDevices {
        UserProfileDevicesSection()
      }

      if clerk.environment?.deleteSelfIsEnabled == true, user?.deleteSelfEnabled == true {
        GroupBox("Delete Account") {
          VStack(alignment: .leading, spacing: 12) {
            Text("Permanently remove this account and all associated data. This action cannot be undone.")
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.danger)
              .fixedSize(horizontal: false, vertical: true)

            HStack {
              Spacer()

              Button("Delete Account") {
                isDeleteAccountPresented = true
              }
              .buttonStyle(.negative(config: .init(emphasis: .low)))
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      HStack {
        Spacer()

        Button("Close") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
      }
    }
    .padding(24)
    .frame(minWidth: 460, maxWidth: 620, alignment: .leading)
    .background(theme.colors.background)
    .task {
      _ = try? await user?.getSessions()
    }
    .task {
      _ = try? await clerk.refreshClient()
    }
    .sheet(isPresented: $isPasswordSheetPresented) {
      UserProfileChangePasswordView(isAddingPassword: user?.passwordEnabled == false)
    }
    .sheet(isPresented: $isDeleteAccountPresented) {
      UserProfileDeleteAccountConfirmationView()
    }
  }
}

#Preview {
  UserProfileSecurityView()
    .environment(Clerk.preview())
}

#endif
