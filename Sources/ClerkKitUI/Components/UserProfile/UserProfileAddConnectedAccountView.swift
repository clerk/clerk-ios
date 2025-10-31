//
//  UserProfileAddConnectedAccountView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/28/25.
//

#if os(iOS)

import FactoryKit
import SwiftUI

struct UserProfileAddConnectedAccountView: View {
    @Environment(Clerk.self) private var clerk
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
            return 0
        } else {
            return 7
        }
    }

    init(contentHeight: Binding<CGFloat> = .constant(0)) {
        self._contentHeight = contentHeight
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
                }
                .padding(24)
                .clerkErrorPresenting($error)
                .navigationBarTitleDisplayMode(.inline)
                .preGlassSolidNavBar()
                .preGlassDetentSheetBackground()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
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
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newValue in
                    contentHeight = newValue + UITabBarController().tabBar.frame.size.height + extraContentHeight
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

extension UserProfileAddConnectedAccountView {

    func connectExternalAccount(provider: OAuthProvider) async {
        guard let user else { return }

        do {
            if provider == .apple {
                let credential = try await SignInWithAppleHelper.getAppleIdCredential()
                try await user.createExternalAccount(provider: .apple, idToken: credential.tokenString)
            } else {
                let newExternalAccount = try await user.createExternalAccount(provider: provider)
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
//    Container.shared.clerk.preview { @MainActor in
//        .mock
//    }

    UserProfileAddConnectedAccountView(contentHeight: .constant(300))
        .clerkPreviewMocks()
        .environment(\.clerkTheme, .clerk)
}

#endif
