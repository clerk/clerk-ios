//
//  SetupMfaTotpSecretView.swift
//  Clerk
//
//  Created by Clerk on 1/29/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SetupMfaTotpSecretView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var error: Error?

  let totp: TOTPResource

  var session: Session? {
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var user: User? {
    session?.user
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Add authenticator application")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "Set up a new sign-in method in your authenticator and enter the Key provided below")
          .padding(.bottom, 32)

        if let secret = totp.secret {
          VStack(spacing: 12) {
            copyableText(secret)

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
          .padding(.bottom, 24)
        }

        if let uri = totp.uri {
          Text("Alternatively, if your authenticator supports TOTP URIs, you can also copy the full URI.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .padding(.bottom, 12)

          VStack(spacing: 12) {
            copyableText(uri)

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
          .padding(.bottom, 24)
        }

        Button {
          navigation.path.append(AuthView.Destination.setupMfaTotpVerify(totp))
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
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          navigation.path.removeLast()
        } label: {
          Image("icon-caret-left", bundle: .module)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
  }

  func copyableText(_ string: String) -> some View {
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
          .strokeBorder(theme.colors.border, lineWidth: 1)
      }
  }

  func copyToClipboard(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
  }
}

#Preview {
  SetupMfaTotpSecretView(totp: .mock)
    .environment(\.clerkTheme, .clerk)
}

#endif
