//
//  SignInFactorOneView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInFactorOneView: View {
  @Environment(\.clerkTheme) private var theme

  let factor: Factor

  @ViewBuilder
  var viewForFactor: some View {
    switch factor.strategy {
    case .passkey:
      SignInFactorOnePasskeyView(factor: factor)
    case .password:
      SignInFactorOnePasswordView(factor: factor)
    case .emailLink:
      SignInFactorOneEmailLinkView(factor: factor)
    case .emailCode,
         .phoneCode,
         .resetPasswordEmailCode,
         .resetPasswordPhoneCode:
      SignInFactorCodeView(factor: factor)
    default:
      GetHelpView(context: .signIn)
    }
  }

  var body: some View {
    viewForFactor
  }
}

#Preview {
  SignInFactorOneView(
    factor: .init(
      strategy: .passkey
    )
  )
}

#endif
