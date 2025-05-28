//
//  UserProfileAddConnectedAccountView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/28/25.
//

#if os(iOS)

  import Factory
  import SwiftUI

  struct UserProfileAddConnectedAccountView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Binding var contentHeight: CGFloat
    @State private var error: Error?

    private var user: User? {
      clerk.user
    }

    private var unconnectedProviders: [OAuthProvider] {
      user?.unconnectedProviders ?? []
    }

    var body: some View {
      NavigationStack {
        VStack(spacing: 24) {
          Text("Link another login option to your account. You’ll need to verify it before it can be used.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.textSecondary)
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
        .background(theme.colors.background)
        .clerkErrorPresenting($error)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.colors.background, for: .navigationBar)
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
              .foregroundStyle(theme.colors.text)
          }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
          proxy.size.height
        } action: { newValue in
          contentHeight = newValue
        }
      }
      .presentationBackground(theme.colors.background)
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
        if error.isCancelledError { return }
        self.error = error
      }
    }

  }

  #Preview {
    let _ = Container.shared.clerk.register(factory: { @MainActor in
      .mock
    })

    UserProfileAddConnectedAccountView(contentHeight: .constant(300))
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
