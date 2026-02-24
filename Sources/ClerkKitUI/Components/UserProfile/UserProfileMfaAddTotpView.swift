//
//  UserProfileMfaAddTotpView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileMfaAddTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileNavigation.self) private var navigation
  @Environment(\.dismiss) private var dismiss

  @State private var path = NavigationPath()
  @State private var error: Error?

  let totp: TOTPResource

  enum Destination: Hashable {
    case verify
    case backupCodes([String])
  }

  @ViewBuilder
  func viewForDestination(_ destination: Destination) -> some View {
    switch destination {
    case .verify:
      UserProfileVerifyView(mode: .totp) { backupCodes in
        if let backupCodes {
          path.append(Destination.backupCodes(backupCodes))
        } else {
          navigation.presentedAddMfaType = nil
        }
      }
    case let .backupCodes(backupCodes):
      BackupCodesView(backupCodes: backupCodes, mfaType: .authenticatorApp)
    }
  }

  private var user: User? {
    clerk.user
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(spacing: 24) {
          if let secret = totp.secret {
            Text("Set up a new sign-in method in your authenticator and enter the Key provided below.\n\nMake sure Time-based or One-time passwords is enabled, then finish linking your account.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)

            VStack(spacing: 12) {
              CopyableTextView(text: secret)

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
              CopyableTextView(text: uri)

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
            path.append(Destination.verify)
          } label: {
            ContinueButtonLabelView()
          }
          .buttonStyle(.primary())
        }
        .padding(24)
      }
      .clerkErrorPresenting($error)
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }

        ToolbarItem(placement: .principal) {
          Text("Add authenticator application", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
      .navigationDestination(for: Destination.self) {
        viewForDestination($0)
      }
    }
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
  }
}

extension UserProfileMfaAddTotpView {
  private func copyToClipboard(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
  }
}

#Preview {
  UserProfileMfaAddTotpView(totp: .mock)
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
