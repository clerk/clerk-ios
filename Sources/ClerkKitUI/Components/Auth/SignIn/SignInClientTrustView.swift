//
//  SignInClientTrustView.swift
//  Clerk
//
//  Created by Tom Milewski on 12/15/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInClientTrustView: View {
  let factor: Factor

  var body: some View {
    switch factor.strategy {
    case .phoneCode, .emailCode:
      SignInFactorCodeView(factor: factor, mode: .clientTrust)
    default:
      GetHelpView(context: .signIn)
    }
  }
}

#Preview {
  SignInClientTrustView(
    factor: .init(
      strategy: .emailCode
    )
  )
  .clerkPreview()
}

#endif
