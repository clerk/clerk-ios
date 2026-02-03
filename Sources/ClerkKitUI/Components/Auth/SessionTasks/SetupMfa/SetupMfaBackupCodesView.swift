//
//  SetupMfaBackupCodesView.swift
//  Clerk
//
//  Created by Clerk on 1/29/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SetupMfaBackupCodesView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  let backupCodes: [String]
  let mfaType: MfaType

  enum MfaType {
    case phoneCode
    case authenticatorApp

    var instructions: LocalizedStringKey {
      switch self {
      case .phoneCode:
        "When signing in, you will need to enter a verification code sent to this phone number as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
      case .authenticatorApp:
        "Two-step verification is now enabled. When signing in, you will need to enter a verification code from this authenticator app as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        Text(mfaType.instructions, bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)

        BackupCodesGrid(backupCodes: backupCodes)

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

        Button {
          finishSetup()
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

        SecuredByClerkView()
      }
      .padding(24)
    }
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
    .navigationBarBackButtonHidden()
  }

  func finishSetup() {
    // Dismiss the entire auth flow
    navigation.dismissAuthFlow?()
  }
}

private func copyToClipboard(_ text: String) {
  #if os(iOS)
  UIPasteboard.general.string = text
  #elseif os(macOS)
  NSPasteboard.general.clearContents()
  NSPasteboard.general.setString(text, forType: .string)
  #endif
}

#Preview {
  SetupMfaBackupCodesView(
    backupCodes: ["abc123", "def456", "ghi789", "jkl012", "mno345", "pqr678", "stu901", "vwx234", "yz567", "abc890"],
    mfaType: .authenticatorApp
  )
  .environment(\.clerkTheme, .clerk)
}

#endif
