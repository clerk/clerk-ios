//
//  SignInFactorOneView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

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
    case "password":
      SignInFactorOnePasswordView()
    case "email_code":
      SignInFactorOneCodeView(strategy: .emailCode)
    case "phone_code":
      SignInFactorOneCodeView(strategy: .phoneCode)
    default:
      SignInGetHelpView()
    }
  }
  
  var body: some View {
    viewForFactor
  }
}

#Preview {
  SignInFactorOneView(factor: .init(strategy: "email_code"))
    .environment(\.clerk, .mock)
}
