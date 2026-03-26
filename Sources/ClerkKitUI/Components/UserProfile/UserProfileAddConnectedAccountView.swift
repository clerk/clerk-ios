//
//  UserProfileAddConnectedAccountView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileAddConnectedAccountView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkUserProfileOAuthConfig) private var oauthConfig
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  @Binding private var contentHeight: CGFloat
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  private var unconnectedProviders: [OAuthProvider] {
    user?.unconnectedProviders ?? []
  }

  var extraContentHeight: CGFloat {
    if #available(iOS 26.0, *) {
      0
    } else {
      7
    }
  }

  init(contentHeight: Binding<CGFloat> = .constant(0)) {
    _contentHeight = contentHeight
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        content
      }
      .scrollBounceBehavior(.basedOnSize)
      .background(theme.colors.background)
      .toolbar {
        ToolbarItem(placement: cancellationPlacement) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }

        ToolbarItem(placement: .principal) {
          Text("Connect account", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
  }
}

extension UserProfileAddConnectedAccountView {
  private var content: some View {
    VStack(spacing: 24) {
      Text("Link another login option to your account. You’ll need to verify it before it can be used.", bundle: .module)
        .font(theme.fonts.subheadline)
        .foregroundStyle(theme.colors.mutedForeground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

      SocialButtonLayout {
        ForEach(unconnectedProviders) { provider in
          SocialButton(provider: provider) {
            await connectExternalAccount(provider: provider)
          }
        }
      }

      #if os(macOS)
      if let error {
        ErrorText(error: error, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      #endif
    }
    .padding(24)
    .background(theme.colors.background)
    #if os(iOS)
      .clerkErrorPresenting($error)
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .preGlassDetentSheetBackground()
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.height
      } action: { newValue in
        contentHeight = newValue + UITabBarController().tabBar.frame.size.height + extraContentHeight
      }
    #endif
  }

  private var cancellationPlacement: ToolbarItemPlacement {
    #if os(iOS)
    .cancellationAction
    #elseif os(macOS)
    .automatic
    #endif
  }

  func connectExternalAccount(provider: OAuthProvider) async {
    guard let user else { return }

    do {
      if provider == .apple {
        try await user.connectAppleAccount()
      } else {
        let newExternalAccount = try await user.createExternalAccount(
          provider: provider,
          additionalScopes: oauthConfig.additionalScopes(for: provider),
          oidcPrompts: oauthConfig.prompts(for: provider)
        )
        try await newExternalAccount.reauthorize()
      }

      dismiss()
    } catch {
      if error.isUserCancelledError { return }
      self.error = error
      ClerkLogger.error("Failed to connect external account", error: error)
    }
  }
}

#Preview {
  UserProfileAddConnectedAccountView(contentHeight: .constant(300))
  #if os(iOS)
    .clerkPreview()
  #elseif os(macOS)
    .environment(Clerk.preview())
  #endif
    .environment(\.clerkTheme, .clerk)
}

#endif
