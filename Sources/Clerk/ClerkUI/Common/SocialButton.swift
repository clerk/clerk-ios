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
  var action: (() -> Void)?

  var body: some View {
    Button {
      if let action {
        action()
      } else {
        defaultAction()
      }
    } label: {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(theme.colors.background)
        .clipShape(.rect(cornerRadius: theme.design.borderRadius))
        .overlay {
          RoundedRectangle(cornerRadius: theme.design.borderRadius)
            .stroke(theme.colors.buttonBorder, lineWidth: 1)
        }
        .tint(theme.colors.neutral)
    }
    .buttonStyle(.scale)
  }
}

extension SocialButton {
  
  func defaultAction() {
    Task {
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
  }

  func onAction(perform action: @escaping () -> Void) -> Self {
    var copy = self
    copy.action = action
    return copy
  }

}

#Preview {
  SocialButton(provider: .google)
    .padding()
}
