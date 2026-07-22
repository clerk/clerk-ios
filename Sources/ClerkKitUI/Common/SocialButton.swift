//
//  SocialButton.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import NukeUI
import SwiftUI

struct SocialButton: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.clerkTheme) private var theme

  let provider: OAuthProvider
  let transferable: Bool
  let unsafeMetadata: JSON?
  let showsTitle: Bool
  var onStart: (() -> Void)?
  var action: (() async -> Void)?
  var result: Result<Void, Error>?
  var onSuccess: ((TransferFlowResult) -> Void)?
  var onError: ((Error) -> Void)?
  var onCancel: (() -> Void)?

  private var fallbackProviderText: some View {
    ViewThatFits(in: .horizontal) {
      if showsTitle {
        Text("Continue with \(provider.name)", bundle: .module)
      }

      Text(provider.name)
    }
    .lineLimit(1)
    .font(theme.fonts.body)
    .foregroundStyle(theme.colors.secondaryButtonForeground)
  }

  private var providerLabel: some View {
    LazyImage(url: provider.iconImageUrl(colorScheme: colorScheme)) { state in
      if let image = state.image {
        ViewThatFits(in: .horizontal) {
          if showsTitle {
            HStack(spacing: 12) {
              ProviderIconView(
                provider: provider,
                image: image,
                foregroundColor: theme.colors.secondaryButtonForeground
              )
              .frame(width: 21, height: 21)

              Text("Continue with \(provider.name)", bundle: .module)
                .lineLimit(1)
                .font(theme.fonts.body)
                .foregroundStyle(theme.colors.secondaryButtonForeground)
            }
          }

          ProviderIconView(
            provider: provider,
            image: image,
            foregroundColor: theme.colors.secondaryButtonForeground
          )
          .frame(width: 21, height: 21)
        }
      } else if state.error != nil {
        fallbackProviderText
      } else {
        fallbackProviderText.hidden()
      }
    }
    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
  }

  init(
    provider: OAuthProvider,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil,
    showsTitle: Bool = true
  ) {
    self.provider = provider
    self.transferable = transferable
    self.unsafeMetadata = unsafeMetadata
    self.showsTitle = showsTitle
  }

  init(
    provider: OAuthProvider,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil,
    showsTitle: Bool = true,
    action: (() async -> Void)? = nil
  ) {
    self.provider = provider
    self.transferable = transferable
    self.unsafeMetadata = unsafeMetadata
    self.showsTitle = showsTitle
    self.action = action
  }

  init(
    provider: OAuthProvider,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil,
    showsTitle: Bool = true,
    onStart: (() -> Void)? = nil,
    onSuccess: ((TransferFlowResult) -> Void)? = nil,
    onError: ((Error) -> Void)? = nil,
    onCancel: (() -> Void)? = nil
  ) {
    self.provider = provider
    self.transferable = transferable
    self.unsafeMetadata = unsafeMetadata
    self.showsTitle = showsTitle
    self.onStart = onStart
    self.onSuccess = onSuccess
    self.onError = onError
    self.onCancel = onCancel
  }

  var body: some View {
    AsyncButton {
      do {
        onStart?()
        if let action {
          await action()
        } else {
          try await defaultAction()
        }
      } catch {
        if error.isUserCancelledError {
          onCancel?()
          return
        } else {
          onError?(error)
        }
      }
    } label: { isRunning in
      providerLabel
        .frame(maxWidth: .infinity)
        .overlayProgressView(isActive: isRunning)
    }
    .buttonStyle(.secondary())
    .accessibilityLabel(Text("Continue with \(provider.name)", bundle: .module))
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.socialProviderButton(strategy: provider.strategy))
  }
}

extension SocialButton {
  func defaultAction() async throws {
    let result: TransferFlowResult = if provider == .apple {
      try await clerk.auth.signInWithApple(
        transferable: transferable,
        unsafeMetadata: unsafeMetadata
      )
    } else {
      try await clerk.auth.signInWithOAuth(
        provider: provider,
        transferable: transferable,
        unsafeMetadata: unsafeMetadata
      )
    }
    onSuccess?(result)
  }
}

#Preview {
  VStack {
    SocialButton(provider: .google)

    HStack {
      SocialButton(provider: .apple, showsTitle: false)
      SocialButton(provider: .google, showsTitle: false)
      SocialButton(provider: .slack, showsTitle: false)
    }
  }
  .padding()
  .environment(Clerk.preview())
}

#endif
