//
//  SignInFactorOneAlternativeMethodsView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/23/25.
//

#if os(iOS)

  import Factory
  import SwiftUI

  struct SignInFactorOneAlternativeMethodsView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState
    
    @State private var error: Error?

    let currentFactor: Factor

    var signIn: SignIn? {
      clerk.client?.signIn
    }

    var alternativeFactors: [Factor] {
      signIn?.alternativeFirstFactors(currentFactor: currentFactor) ?? []
    }

    var socialProviders: [OAuthProvider] {
      clerk.environment.authenticatableSocialProviders
    }

    func actionText(factor: Factor) -> LocalizedStringKey? {
      switch factor.strategy {
      case "phone_code":
        guard let safeIdentifier = factor.safeIdentifier else { return nil }
        return "Send SMS code to \(safeIdentifier.formattedAsPhoneNumberIfPossible)"
      case "email_code":
        guard let safeIdentifier = factor.safeIdentifier else { return nil }
        return "Email code to \(safeIdentifier)"
      case "passkey":
        return "Sign in with your passkey"
      case "password":
        return "Sign in with your password"
      case "totp":
        return "Use your authenticator app"
      case "backup_code":
        return "Use a backup code"
      default:
        return nil
      }
    }

    func iconName(factor: Factor) -> String? {
      switch factor.strategy {
      case "password":
        return "icon-lock"
      case "phone_code":
        return "icon-sms"
      case "email_code":
        return "icon-email"
      case "passkey":
        return "icon-fingerprint"
      default:
        return nil
      }
    }

    var body: some View {
      ScrollView {
        VStack(spacing: 0) {
          AppLogoView()
            .frame(maxHeight: 44)
            .padding(.bottom, 24)

          VStack(spacing: 8) {
            HeaderView(style: .title, text: "Use another method")
            HeaderView(style: .subtitle, text: "Facing issues? You can use any of these methods to sign in.")
          }
          .padding(.bottom, 32)

          VStack(spacing: 16) {
            SocialButtonLayout {
              ForEach(socialProviders) { provider in
                SocialButton(provider: provider) {
                  await signInWithProvider(provider)
                }
                .simultaneousGesture(TapGesture())
              }
            }

            TextDivider(string: "or")

            ForEach(alternativeFactors, id: \.self) { factor in
              if let actionText = actionText(factor: factor) {
                Button {
                  authState.path.append(AuthState.Destination.signInFactorOne(factor: factor))
                } label: {
                  HStack(spacing: 6) {
                    if let iconName = iconName(factor: factor) {
                      Image(iconName, bundle: .module)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .scaledToFit()
                        .foregroundStyle(theme.colors.textSecondary)
                    }
                    Text(actionText, bundle: .module)
                      .font(theme.fonts.body)
                      .foregroundStyle(theme.colors.text)
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
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
    }
  }

  extension SignInFactorOneAlternativeMethodsView {

    func signInWithProvider(_ provider: OAuthProvider) async {
      do {
        guard let signIn else {
          authState.path = NavigationPath()
          return
        }
        
        var result: TransferFlowResult
        
        if provider == .apple {
          result = try await SignInWithAppleUtils.signIn()
        } else {
          result = try await signIn
            .prepareFirstFactor(strategy: .oauth(provider: provider))
            .authenticateWithRedirect()
        }
        
        switch result {
        case .signIn(let signIn):
          authState.setToStepForStatus(signIn: signIn)
        case .signUp(let signUp):
          // TODO: Set to sign up status
          return
        }
      } catch {
        if error.isCancelledError { return }
        self.error = error
      }
    }

  }

  #Preview {
    SignInFactorOneAlternativeMethodsView(
      currentFactor: .mockEmailCode
    )
    .environment(\.clerk, .mock)
  }

#endif
