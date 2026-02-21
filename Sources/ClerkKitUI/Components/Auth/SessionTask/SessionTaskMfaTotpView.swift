//
//  SessionTaskMfaTotpView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskMfaTotpView: View {
  @Environment(\.clerkTheme) private var theme

  @State private var showVerify = false

  let totp: TOTPResource
  let onDone: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        SessionTaskHeaderSection(
          title: "Add authenticator application",
          subtitle: "Set up a new sign-in method in your authenticator app and scan the following QR code to link it to your account."
        )
        .padding(.bottom, 32)

        if let secret = totp.secret {
          VStack(spacing: 12) {
            VStack(spacing: 6) {
              Text("Manual setup key", bundle: .module)
                .font(theme.fonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)

              Text("Make sure Time-based or One-time passwords is enabled, then finish linking your account.", bundle: .module)
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }

            copyableText(secret)

            Button {
              UIPasteboard.general.string = secret
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
          .padding(.bottom, 32)
        }

        Button {
          showVerify = true
        } label: {
          ContinueButtonLabelView()
        }
        .buttonStyle(.primary())
        .padding(.bottom, 32)

        SecuredByClerkView()
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .navigationDestination(isPresented: $showVerify) {
      SessionTaskMfaVerifyTotpView(onDone: onDone)
    }
  }

  private func copyableText(_ string: String) -> some View {
    Text(verbatim: string)
      .font(theme.fonts.subheadline)
      .foregroundStyle(theme.colors.foreground)
      .frame(maxWidth: .infinity, minHeight: 20)
      .lineLimit(1)
      .padding(.vertical, 18)
      .padding(.horizontal, 16)
      .background(theme.colors.muted)
      .clipShape(.rect(cornerRadius: theme.design.borderRadius))
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.inputBorder, lineWidth: 1)
      }
  }
}

#endif
