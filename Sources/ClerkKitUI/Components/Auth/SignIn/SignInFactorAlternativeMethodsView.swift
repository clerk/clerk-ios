//
//  SignInFactorAlternativeMethodsView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInFactorAlternativeMethodsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState

  @State private var error: Error?

  let currentFactor: Factor
  var isSecondFactor: Bool = false

  var signIn: SignIn? {
    clerk.auth.currentSignIn
  }

  var alternativeFactors: [Factor] {
    if isSecondFactor {
      signIn?.alternativeSecondFactors(currentFactor: currentFactor) ?? []
    } else {
      signIn?.alternativeFirstFactors(currentFactor: currentFactor) ?? []
    }
  }

  var socialProviders: [OAuthProvider] {
    if isSecondFactor {
      []
    } else {
      clerk.environment?.authenticatableSocialProviders ?? []
    }
  }

  func actionText(factor: Factor) -> LocalizedStringKey? {
    switch factor.strategy {
    case .phoneCode, .emailCode, .emailLink:
      identifierActionText(factor: factor)
    case .passkey:
      "Sign in with your passkey"
    case .password:
      "Sign in with your password"
    case .totp:
      "Use your authenticator app"
    case .backupCode:
      "Use a backup code"
    default:
      nil
    }
  }

  func identifierActionText(factor: Factor) -> LocalizedStringKey? {
    guard let safeIdentifier = factor.safeIdentifier else { return nil }

    switch factor.strategy {
    case .phoneCode:
      return "Send SMS code to \(safeIdentifier.formattedAsPhoneNumberIfPossible)"
    case .emailCode:
      return "Email code to \(safeIdentifier)"
    case .emailLink:
      return "Email link to \(safeIdentifier)"
    default:
      return nil
    }
  }

  func iconName(factor: Factor) -> String? {
    switch factor.strategy {
    case .password:
      "icon-lock"
    case .phoneCode:
      "icon-sms"
    case .emailCode:
      "icon-email"
    case .emailLink:
      "icon-email"
    case .passkey:
      "icon-fingerprint"
    case .totp:
      "icon-key"
    case .backupCode:
      "icon-lock"
    default:
      nil
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Use another method")
          HeaderView(style: .subtitle, text: "Facing issues? You can use any of these methods to sign in.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 16) {
          SocialButtonLayout {
            ForEach(socialProviders) { provider in
              SocialButton(provider: provider, transferable: authState.transferable) {
                await signInWithProvider(provider)
              }
              .simultaneousGesture(TapGesture())
            }
          }

          if !socialProviders.isEmpty, !alternativeFactors.isEmpty {
            TextDivider(string: "or")
          }

          ForEach(alternativeFactors, id: \.self) { factor in
            if let actionText = actionText(factor: factor) {
              Button {
                if isSecondFactor {
                  navigation.path.append(
                    AuthView.Destination.signInFactorTwo(factor: factor)
                  )
                } else {
                  navigation.path.append(
                    AuthView.Destination.signInFactorOne(factor: factor)
                  )
                }
              } label: {
                if let iconName = iconName(factor: factor) {
                  StrategyOptionButton(iconName: iconName, text: actionText)
                } else {
                  Text(actionText, bundle: .module)
                    .font(theme.fonts.body)
                    .foregroundStyle(theme.colors.foreground)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                }
              }
              .buttonStyle(.secondary())
              .simultaneousGesture(TapGesture())
            }
          }
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .clerkErrorPresenting($error)
    .background(theme.colors.background)
  }
}

extension SignInFactorAlternativeMethodsView {
  func signInWithProvider(_ provider: OAuthProvider) async {
    do {
      guard let signIn else {
        navigation.path = []
        return
      }

      let result: TransferFlowResult =
        if provider == .apple {
          try await signIn.authenticateWithApple(transferable: authState.transferable)
        } else {
          try await signIn.authenticateWithOAuth(provider: provider, transferable: authState.transferable)
        }

      switch result {
      case .signIn(let signIn):
        navigation.setToStepForStatus(signIn: signIn)
      case .signUp(let signUp):
        navigation.setToStepForStatus(signUp: signUp)
      }

    } catch {
      if error.isUserCancelledError { return }
      self.error = error
      ClerkLogger.error("Failed to sign in with OAuth provider", error: error)
    }
  }
}

#Preview {
  SignInFactorAlternativeMethodsView(
    currentFactor: .mockEmailCode
  )
  .clerkPreview()
}

#endif
