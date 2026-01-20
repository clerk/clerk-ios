//
//  SocialButton.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct SocialButton: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  let provider: OAuthProvider
  var action: (() async -> Void)?
  var result: Result<Void, Error>?
  var onSuccess: ((TransferFlowResult) -> Void)?
  var onError: ((Error) -> Void)?

  private var iconImage: some View {
    LazyImage(url: provider.iconImageUrl(darkMode: colorScheme == .dark)) { state in
      if let image = state.image {
        image
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "globe")
          .resizable()
          .scaledToFit()
      }
    }
    .frame(width: 21, height: 21)
    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
  }

  init(
    provider: OAuthProvider
  ) {
    self.provider = provider
  }

  init(
    provider: OAuthProvider,
    action: (() async -> Void)? = nil
  ) {
    self.provider = provider
    self.action = action
  }

  init(
    provider: OAuthProvider,
    onSuccess: ((TransferFlowResult) -> Void)? = nil,
    onError: ((Error) -> Void)? = nil
  ) {
    self.provider = provider
    self.onSuccess = onSuccess
    self.onError = onError
  }

  var body: some View {
    AsyncButton {
      do {
        if let action {
          await action()
        } else {
          try await defaultAction()
        }
      } catch {
        if error.isUserCancelledError {
          return
        } else {
          onError?(error)
        }
      }
    } label: { isRunning in
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          iconImage
          Text("Continue with \(provider.name)", bundle: .module)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.foreground)
        }

        iconImage
      }
      .frame(maxWidth: .infinity)
      .overlayProgressView(isActive: isRunning)
    }
    .buttonStyle(.secondary())
    .overlay(alignment: .topTrailing) {
      if LastUsedAuthBadge.shouldShow(for: .oauth(provider)) {
        Badge(key: "Last Used", style: .secondary)
          .lastUsedAuthBadgeStyle()
      }
    }
  }
}

extension SocialButton {
  func defaultAction() async throws {
    let result: TransferFlowResult = if provider == .apple {
      try await clerk.auth.signInWithApple()
    } else {
      try await clerk.auth.signInWithOAuth(provider: provider)
    }
    onSuccess?(result)
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

#endif
