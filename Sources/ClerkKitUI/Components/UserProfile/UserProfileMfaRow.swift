//
//  UserProfileMfaRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileMfaRow: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var isConfirmingRemoval = false
  @State private var removeResource: RemoveResource?
  @State private var backupCodes: BackupCodeResource?
  @State private var isLoading = false
  @State private var error: Error?

  var user: User? {
    clerk.user
  }

  enum Style {
    case authenticatorApp
    case sms(phoneNumber: PhoneNumber)
    case backupCodes
  }

  private var icon: Image {
    switch style {
    case .authenticatorApp:
      Image("icon-key", bundle: .module)
    case .sms:
      Image("icon-phone", bundle: .module)
    case .backupCodes:
      Image("icon-lock", bundle: .module)
    }
  }

  private var text: Text {
    switch style {
    case .authenticatorApp:
      Text("Authenticator app", bundle: .module)
    case .sms:
      Text("SMS code", bundle: .module)
    case .backupCodes:
      Text("Backup codes", bundle: .module)
    }
  }

  @ViewBuilder
  private var menuItems: some View {
    switch style {
    case .authenticatorApp:
      Button("Remove", role: .destructive) {
        removeResource = .totp
      }
    case let .sms(phoneNumber):
      if user?.totpEnabled != true, !phoneNumber.defaultSecondFactor {
        AsyncButton {
          await makeDefaultSecondFactor(phoneNumber: phoneNumber)
        } label: { _ in
          Text("Set as default")
        }
        .onIsRunningChanged { isLoading = $0 }
        .onDisappear { isLoading = false }
      }

      Button("Remove", role: .destructive) {
        removeResource = .secondFactorPhoneNumber(phoneNumber)
      }
    case .backupCodes:
      AsyncButton {
        await regenerateBackupCodes()
      } label: { _ in
        Text("Regenerate", bundle: .module)
      }
      .onIsRunningChanged { isLoading = $0 }
    }
  }

  let style: Style
  var isDefault: Bool = false

  var body: some View {
    HStack(spacing: 0) {
      HStack(alignment: .top, spacing: 16) {
        icon
          .resizable()
          .scaledToFit()
          .frame(width: 24, height: 24)
          .foregroundStyle(theme.colors.mutedForeground)
        VStack(alignment: .leading, spacing: 4) {
          if isDefault {
            Badge(key: "Default", style: .secondary)
          }

          HStack(spacing: 4) {
            text
            if case let .sms(phoneNumber) = style {
              Text(verbatim: phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
            }
          }
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .frame(minHeight: 22)
        }
      }

      Spacer(minLength: 0)

      Menu {
        menuItems
      } label: {
        Image("icon-three-dots-vertical", bundle: .module)
          .resizable()
          .scaledToFit()
          .foregroundColor(theme.colors.mutedForeground)
          .frame(width: 20, height: 20)
      }
      .frame(width: 30, height: 30)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
    .overlayProgressView(isActive: isLoading)
    .overlay(alignment: .bottom) {
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(theme.colors.border)
    }
    .onChange(of: removeResource) {
      if $1 != nil { isConfirmingRemoval = true }
    }
    .confirmationDialog(
      removeResource?.messageLine1 ?? "",
      isPresented: $isConfirmingRemoval,
      titleVisibility: .visible,
      actions: {
        AsyncButton(role: .destructive) {
          await removeResource()
        } label: { _ in
          Text(removeResource?.title ?? "", bundle: .module)
        }
        .onIsRunningChanged { isLoading = $0 }

        Button(role: .cancel) {
          isConfirmingRemoval = false
          removeResource = nil
        } label: {
          Text("Cancel", bundle: .module)
        }
      }
    )
    .sheet(item: $backupCodes) { backupCodes in
      NavigationStack {
        BackupCodesView(backupCodes: backupCodes.codes)
      }
    }
  }
}

extension UserProfileMfaRow {
  private func removeResource() async {
    defer { removeResource = nil }

    do {
      try await removeResource?.deleteAction()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to remove MFA resource", error: error)
    }
  }

  private func makeDefaultSecondFactor(phoneNumber: PhoneNumber) async {
    do {
      try await phoneNumber.makeDefaultSecondFactor()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to make phone number default second factor", error: error)
    }
  }

  private func regenerateBackupCodes() async {
    guard let user else { return }

    do {
      backupCodes = try await user.createBackupCodes()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to regenerate backup codes", error: error)
    }
  }
}

#Preview {
  UserProfileMfaRow(
    style: .authenticatorApp,
    isDefault: true
  )

  UserProfileMfaRow(
    style: .sms(phoneNumber: .mock)
  )

  UserProfileMfaRow(
    style: .backupCodes
  )
}

#endif
