//
//  BackupCodesView+macOS.swift
//  Clerk
//

#if os(macOS)

import AppKit
import SwiftUI

struct BackupCodesView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  enum MfaType {
    case phoneCode
    case authenticatorApp
    case backupCodes

    var instructions: String {
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

  private let columns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Backup Codes")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text(mfaType.instructions)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: 16) {
        Text("Backup codes")
          .font(theme.fonts.caption)
          .foregroundStyle(theme.colors.mutedForeground)

        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(backupCodes, id: \.self) { code in
            Text(code)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.foreground)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding(16)
      .background(theme.colors.muted, in: RoundedRectangle(cornerRadius: 14))

      HStack {
        Button("Copy to Clipboard") {
          copyToClipboard(backupCodes.joined(separator: ", "))
        }
        .buttonStyle(.secondary(config: .init(emphasis: .low)))

        Spacer()

        Button("Done") {
          dismiss()
        }
        .buttonStyle(.primary())
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(minWidth: 460, maxWidth: 620, alignment: .leading)
    .background(theme.colors.background)
  }
}

private func copyToClipboard(_ text: String) {
  NSPasteboard.general.clearContents()
  NSPasteboard.general.setString(text, forType: .string)
}

#Preview {
  BackupCodesView(
    backupCodes: ["abc", "def", "ghi", "jkl", "lmn", "opq", "rst", "uvw"],
    mfaType: .authenticatorApp
  )
}

#endif
