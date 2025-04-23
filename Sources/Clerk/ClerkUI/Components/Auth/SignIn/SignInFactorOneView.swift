//
//  SignInFactorOneView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct SignInFactorOneView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  
  let factor: Factor

  var signIn: SignIn? {
    clerk.client?.signIn
  }
  
  @ViewBuilder
  var viewForFactor: some View {
    switch factor.strategy {
    case "passkey":
      SignInFactorOnePasskeyView(factor: factor)
    case "password":
      SignInFactorOnePasswordView(factor: factor)
    case "email_code":
      SignInFactorOneCodeView(factor: factor)
    case "phone_code":
      SignInFactorOneCodeView(factor: factor)
    default:
      SignInGetHelpView()
    }
  }
  
  var body: some View {
    viewForFactor
      .background(theme.colors.background)
  }
}

#Preview {
  SignInFactorOneView(
    factor: .init(
      strategy: "passkey"
    )
  )
  .environment(\.clerk, .mock)
}

#endif
