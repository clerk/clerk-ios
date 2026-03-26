//
//  BackupCodesView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct BackupCodesView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileSheetNavigation.self) private var navigation
  @Environment(\.dismiss) private var dismiss

  enum MfaType {
    case phoneCode
    case authenticatorApp
    case backupCodes

    var instructions: LocalizedStringKey {
      switch self {
      case .phoneCode:
        "When signing in, you will need to enter a verification code sent to this phone number as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
      case .authenticatorApp:
        "Two-step verification is now enabled. When signing in, you will need to enter a verification code from this authenticator app as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
      case .backupCodes:
        "Backup codes are now enabled. You can use one of these to sign in to your account, if you lose access to your authentication device. Each code can only be used once."
      }
    }
  }

  let backupCodes: [String]
  var mfaType: MfaType = .backupCodes

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
      }
      .padding(24)
    }
    #if os(macOS)
    .frame(minWidth: 460, maxWidth: 620)
    #endif
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
    #endif
      .preGlassSolidNavBar()
      .toolbar {
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            done()
          } label: {
            Text("Done", bundle: .module)
              .font(theme.fonts.body)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.primary)
          }
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.BackupCodes.doneButton)
        }
        #elseif os(macOS)
        ToolbarItem {
          Button {
            done()
          } label: {
            Text("Done", bundle: .module)
              .font(theme.fonts.body)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.primary)
          }
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.UserProfile.BackupCodes.doneButton)
        }
        #endif

        ToolbarItem(placement: .principal) {
          Text("Backup codes", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
  }
}

extension BackupCodesView {
  private func done() {
    switch mfaType {
    case .phoneCode, .authenticatorApp:
      navigation.presentedAddMfaType = nil
    case .backupCodes:
      dismiss()
    }
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

struct BackupCodesGrid: View {
  @Environment(\.clerkTheme) private var theme

  let backupCodes: [String]

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  var body: some View {
    VStack(spacing: 20) {
      Text("Backup codes", bundle: .module)
        .font(theme.fonts.caption)
        .foregroundStyle(theme.colors.mutedForeground)
      LazyVGrid(columns: columns, spacing: 24) {
        ForEach(backupCodes, id: \.self) { code in
          Text(code)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .padding(.top, 6)
    .padding(.bottom, 20)
    .padding(.horizontal, 16)
    .overlay {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .strokeBorder(theme.colors.border, lineWidth: 1)
    }
  }
}

#Preview {
  BackupCodesView(
    backupCodes: ["abc", "def", "ghi", "jkl", "lmn", "opq", "rst", "uvw", "xyz"],
    mfaType: .authenticatorApp
  )
  .clerkPreview()
  .environment(UserProfileSheetNavigation())
}

#endif
