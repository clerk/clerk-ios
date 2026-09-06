//
//  SignInFactorAlternativeMethodsView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import SwiftUI

struct SignInFactorAlternativeMethodsView: View {
  @SwiftUI.Environment(ClerkJSCore.Clerk.self) private var jsClerk
  @SwiftUI.Environment(\.clerkTheme) private var theme
  @SwiftUI.Environment(AuthNavigation.self) private var navigation
  @SwiftUI.Environment(AuthState.self) private var authState

  let currentFactor: Factor
  let mode: SignInFactorMode

  @State private var error: Error?

  var alternativeFactors: [Factor] {
    guard jsClerk.client.signIn.id != nil else { return [] }
    let signIn = JSCoreAuthMapping.signIn(from: jsClerk.client.signIn)
    if mode.usesSecondFactorAPI {
      return signIn.alternativeSecondFactors(currentFactor: currentFactor)
    }
    return signIn.alternativeFirstFactors(currentFactor: currentFactor)
  }

  var socialProviders: [OAuthProvider] {
    if mode.usesSecondFactorAPI {
      []
    } else {
      JSCoreAuthMapping.oauthProviders(
        from: jsClerk.environment?.authenticatableSocialProviders ?? []
      )
    }
  }

  init(
    currentFactor: Factor,
    mode: SignInFactorMode = .firstFactor
  ) {
    self.currentFactor = currentFactor
    self.mode = mode
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
          SocialButtonGroup(providers: socialProviders) { provider, showsTitle, _ in
            SocialButton(
              provider: provider,
              transferable: authState.transferable,
              unsafeMetadata: authState.unsafeMetadata,
              showsTitle: showsTitle,
              onSuccess: { result in
                switch result {
                case .signIn(let signIn):
                  navigation.setToStepForStatus(signIn: signIn)
                case .signUp(let signUp):
                  navigation.setToStepForStatus(signUp: signUp)
                }
              },
              onError: { error in
                self.error = error
              }
            )
            .simultaneousGesture(TapGesture())
          }

          if !socialProviders.isEmpty, !alternativeFactors.isEmpty {
            TextDivider(string: "or")
          }

          ForEach(alternativeFactors, id: \.self) { factor in
            if let actionText = actionText(factor: factor) {
              Button {
                navigation.path.append(mode.destination(for: factor))
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
              .accessibilityIdentifier(
                ClerkAccessibilityIdentifiers.Auth.SignIn.alternativeMethodButton(strategy: factor.strategy.rawValue)
              )
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

#Preview {
  SignInFactorAlternativeMethodsView(
    currentFactor: .mockEmailCode
  )
  .clerkPreview()
}

#endif
