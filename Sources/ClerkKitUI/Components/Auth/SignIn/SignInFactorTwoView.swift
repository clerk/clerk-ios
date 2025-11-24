//
//  SignInFactorTwoView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInFactorTwoView: View {
  @Environment(\.clerkTheme) private var theme

  let factor: Factor

  @ViewBuilder
  var viewForFactor: some View {
    switch factor.strategy {
    case "totp", "phone_code", "email_code":
      SignInFactorCodeView(factor: factor, isSecondFactor: true)
    case "backup_code":
      SignInFactorTwoBackupCodeView(factor: factor)
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
      strategy: "totp"
    )
  )
}

#endif
