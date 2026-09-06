//
//  SignInFactorOneForgotPasswordView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import SwiftUI

struct SignInFactorOneForgotPasswordView: View {
  @SwiftUI.Environment(ClerkJSCore.Clerk.self) private var jsClerk
  @SwiftUI.Environment(\.clerkTheme) private var theme
  @SwiftUI.Environment(AuthNavigation.self) private var navigation
  @SwiftUI.Environment(AuthState.self) private var authState

  @State private var error: Error?

  var alternativeFactors: [Factor] {
    guard jsClerk.client.signIn.id != nil else { return [] }
    let signIn = JSCoreAuthMapping.signIn(from: jsClerk.client.signIn)
    return signIn.alternativeFirstFactors(currentFactor: nil).filter { $0.strategy != .password }
  }

  var socialProviders: [OAuthProvider] {
    JSCoreAuthMapping.oauthProviders(
      from: jsClerk.environment?.authenticatableSocialProviders ?? []
    )
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
    case .emailCode, .emailLink:
      "icon-email"
    case .passkey:
      "icon-fingerprint"
    default:
      nil
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Forgot password?")
          .padding(.bottom, 32)

        VStack(spacing: 16) {
          AsyncButton {
            await resetPassword()
          } label: { isRunning in
            Text("Reset your password", bundle: .module)
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.primaryForeground)
              }
          }
          .buttonStyle(.primary())
          .simultaneousGesture(TapGesture())

          TextDivider(string: "Or, sign in with another method")

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

          ForEach(alternativeFactors, id: \.self) { factor in
            if let actionText = actionText(factor: factor) {
              Button {
                navigation.path.append(
                  AuthView.Destination.signInFactorOne(factor: factor)
                )
              } label: {
                HStack(spacing: 6) {
                  if let iconName = iconName(factor: factor) {
                    Image(iconName, bundle: .module)
                      .resizable()
                      .frame(width: 16, height: 16)
                      .scaledToFit()
                      .foregroundStyle(theme.colors.mutedForeground)
                  }
                  Text(actionText, bundle: .module)
                    .font(theme.fonts.body)
                    .foregroundStyle(theme.colors.foreground)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity)
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

extension SignInFactorOneForgotPasswordView {
  func resetPassword() async {
    guard jsClerk.client.signIn.id != nil else {
      navigation.path = []
      return
    }

    let signIn = JSCoreAuthMapping.signIn(from: jsClerk.client.signIn)
    guard let resetFactor = signIn.resetPasswordFactor else {
      navigation.path = []
      return
    }

    navigation.path.append(
      AuthView.Destination.signInFactorOne(factor: resetFactor)
    )
  }
}

#Preview {
  SignInFactorOneForgotPasswordView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
