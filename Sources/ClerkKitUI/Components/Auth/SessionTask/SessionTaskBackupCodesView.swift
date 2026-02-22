//
//  SessionTaskBackupCodesView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskBackupCodesView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  let backupCodes: [String]
  let mfaType: BackupCodesMfaType
  
  enum BackupCodesMfaType {
    case phoneCode
    case authenticatorApp
  }

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
          navigation.handleSessionTaskCompletion(session: clerk.session)
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

#endif
