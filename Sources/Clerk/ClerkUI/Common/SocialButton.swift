//
//  SocialButton.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

import Kingfisher
import SwiftUI

struct SocialButton: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  let provider: OAuthProvider
  var action: (() async -> Void)?
  
  private var iconImage: some View {
    KFImage(provider.iconImageUrl(darkMode: colorScheme == .dark))
      .resizable()
      .placeholder {
        Image(systemName: "globe")
          .resizable()
          .scaledToFit()
          .frame(width: 21, height: 21)
      }
      .scaledToFit()
      .frame(width: 21, height: 21)
  }

  var body: some View {
    AsyncButton {
      if let action {
        await action()
      } else {
        await defaultAction()
      }
    } label: { isRunning in
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          iconImage
          Text("Continue with \(provider.name)", bundle: .module)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.text)
        }
        
        iconImage
      }
      .frame(maxWidth: .infinity)
      .overlayProgressView(isActive: isRunning)
    }
    .buttonStyle(.secondary())
  }
}

extension SocialButton {
  
  func defaultAction() async {
    do {
      if provider == .apple {
        try await SignInWithAppleUtils.signIn()
      } else {
        try await SignIn.authenticateWithRedirect(
          strategy: .oauth(provider: provider)
        )
      }
    } catch {
      dump(error)
    }
  }

  func onAction(perform action: @escaping () -> Void) -> Self {
    var copy = self
    copy.action = action
    return copy
  }

}

#Preview {
  
  VStack {
    SocialButton(provider: .google)

    HStack {
      SocialButton(provider: .apple)
      SocialButton(provider: .google)
      SocialButton(provider: .slack)
    }
  }
  .padding()
}
