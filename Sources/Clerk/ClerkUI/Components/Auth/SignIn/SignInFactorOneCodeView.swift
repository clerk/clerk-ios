//
//  SignInFactorOneCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

import SwiftUI

struct SignInFactorOneCodeView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.authState) private var authState

  @State private var code = ""
  @State private var resendSeconds = 1
  @State private var error: Error?
  @FocusState private var isFocused: Bool

  var signIn: SignIn? {
    clerk.client?.signIn
  }

  let factor: Factor

  var title: LocalizedStringKey {
    switch factor.strategy {
    case "email_code":
      "Check your email"
    case "phone_code":
      "Check your phone"
    default:
      ""
    }
  }

  var subtitleString: LocalizedStringKey {
    if let appName = clerk.environment.displayConfig?.applicationName {
      return "to continue to \(appName)"
    } else {
      return "to continue"
    }
  }

  var hasBeenPrepared: Bool {
    switch factor.strategy {
    case "email_code":
      signIn?.firstFactorVerification?.strategy == "email_code"
    case "phone_code":
      signIn?.firstFactorVerification?.strategy == "phone_code"
    default:
      false
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: title)
          HeaderView(style: .subtitle, text: subtitleString)

          if let identifier = signIn?.identifier {
            Button {
              authState.path = NavigationPath()
            } label: {
              IdentityPreviewView(label: identifier)
            }
            .buttonStyle(.secondary(config: .init(size: .small)))
          }
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          OTPField(code: $code)
            .onCodeEntry {
              Task {
                await attempt()
              }
            }

          AsyncButton {
            // resend
          } label: { isRunning in
            Text("Didn't recieve a code? Resend (\(resendSeconds))", bundle: .module)
              .font(theme.fonts.subheadline)
          }
          .buttonStyle(.secondary(config: .init(emphasis: .none, size: .small)))

          Button {
            authState.path.append(
              AuthState.Destination.signInFactorOneUseAnotherMethod(
                currentFactor: factor
              )
            )
          } label: {
            Text("Use another method", bundle: .module)
              .font(theme.fonts.subheadline)
          }
          .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .task {
      if !hasBeenPrepared {
        await prepare()
      }
    }
  }
}

extension SignInFactorOneCodeView {

  func prepare() async {
    isFocused = false

    guard let signIn else {
      authState.path = NavigationPath()
      return
    }

    do {
      switch factor.strategy {
      case "email_code":
        try await signIn.prepareFirstFactor(
          strategy: .emailCode(emailAddressId: factor.emailAddressId)
        )
      case "phone_code":
        try await signIn.prepareFirstFactor(
          strategy: .phoneCode(phoneNumberId: factor.phoneNumberId)
        )
      default:
        return
      }
    } catch {
      self.error = error
    }
  }

  func attempt() async {
    guard let signIn else {
      authState.path = NavigationPath()
      return
    }

    do {
      switch factor.strategy {
      case "email_code":
        try await signIn.attemptFirstFactor(strategy: .emailCode(code: code))
      case "phone_code":
        try await signIn.attemptFirstFactor(strategy: .phoneCode(code: code))
      default:
        return
      }
    } catch {
      self.error = error
    }
  }

}

#Preview("Email Code") {
  SignInFactorOneCodeView(factor: .mockEmailCode)
    .environment(\.clerk, .mock)
}

#Preview("Phone Code") {
  SignInFactorOneCodeView(factor: .mockEmailCode)
    .environment(\.clerk, .mock)
}
