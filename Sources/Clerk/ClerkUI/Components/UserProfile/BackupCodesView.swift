//
//  BackupCodesView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/6/25.
//

#if os(iOS)

  import SwiftUI

  struct BackupCodesView: View {
    @Environment(\.clerkTheme) private var theme
    @Environment(\.userProfileSharedState) private var sharedState
    @Environment(\.dismiss) private var dismiss

    enum MfaType {
      case phoneCode
      case authenticatorApp
      case backupCodes

      var instructions: LocalizedStringKey {
        switch self {
        case .phoneCode:
          return "When signing in, you will need to enter a verification code sent to this phone number as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
        case .authenticatorApp:
          return "Two-step verification is now enabled. When signing in, you will need to enter a verification code from this authenticator app as an additional step.\n\nSave these backup codes and store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in."
        case .backupCodes:
          return "Backup codes are now enabled. You can use one of these to sign in to your account, if you lose access to your authentication device. Each code can only be used once."
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
            .foregroundStyle(theme.colors.textSecondary)
          BackupCodesGrid(backupCodes: backupCodes)
          Button {
            copyToClipboard(backupCodes.joined(separator: ", "))
          } label: {
            HStack(spacing: 6) {
              Image("icon-clipboard", bundle: .module)
                .foregroundStyle(theme.colors.textSecondary)
              Text("Copy to clipboard", bundle: .module)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.secondary())
        }
        .padding(24)
      }
      .background(theme.colors.background)
      .presentationBackground(theme.colors.background)
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
      .preGlassSolidNavBar()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            switch mfaType {
            case .phoneCode, .authenticatorApp:
              sharedState.presentedAddMfaType = nil
            case .backupCodes:
              dismiss()
            }
          } label: {
            Text("Done", bundle: .module)
              .font(theme.fonts.body)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.primary)
          }
        }

        ToolbarItem(placement: .principal) {
          Text("Backup codes", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.text)
        }
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
          .foregroundStyle(theme.colors.textSecondary)
        LazyVGrid(columns: columns, spacing: 24) {
          ForEach(backupCodes, id: \.self) { code in
            Text(code)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.text)
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
  }

#endif
