//
//  UserProfileMfaAddTotpView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/12/25.
//

#if os(iOS)

  import FactoryKit
  import SwiftUI

  struct UserProfileMfaAddTotpView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.userProfileSharedState) private var sharedState
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
            sharedState.presentedAddMfaType = nil
          }
        }
      case .backupCodes(let backupCodes):
        BackupCodesView(backupCodes: backupCodes, mfaType: .authenticatorApp)
      }
    }

    private var user: User? { clerk.user }

    var body: some View {
      NavigationStack(path: $path) {
        ScrollView {
          VStack(spacing: 24) {
            if let secret = totp.secret {
              Text("Set up a new sign-in method in your authenticator and enter the Key provided below.\n\nMake sure Time-based or One-time passwords is enabled, then finish linking your account.", bundle: .module)
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.textSecondary)

              VStack(spacing: 12) {
                copyableText(secret)

                Button {
                  copyToClipboard(secret)
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
            }

            if let uri = totp.uri {
              Text("Alternatively, if your authenticator supports TOTP URIs, you can also copy the full URI.", bundle: .module)
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.textSecondary)

              VStack(spacing: 12) {
                copyableText(uri)

                Button {
                  copyToClipboard(uri)
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
            }

            Button {
              path.append(Destination.verify)
            } label: {
              HStack(spacing: 4) {
                Text("Continue", bundle: .module)
                Image("icon-triangle-right", bundle: .module)
                  .foregroundStyle(theme.colors.textOnPrimaryBackground)
                  .opacity(0.6)
              }
              .frame(maxWidth: .infinity)
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
              .foregroundStyle(theme.colors.text)
          }
        }
        .navigationDestination(for: Destination.self) {
          viewForDestination($0)
        }
      }
      .presentationBackground(theme.colors.background)
      .background(theme.colors.background)
    }

    @ViewBuilder
    func copyableText(_ string: String) -> some View {
      Text(verbatim: string)
        .font(theme.fonts.subheadline)
        .foregroundStyle(theme.colors.text)
        .frame(maxWidth: .infinity, minHeight: 20)
        .lineLimit(1)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(theme.colors.backgroundSecondary)
        .clipShape(.rect(cornerRadius: theme.design.borderRadius))
        .overlay {
          RoundedRectangle(cornerRadius: theme.design.borderRadius)
            .strokeBorder(theme.colors.border, lineWidth: 1)
        }
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
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
