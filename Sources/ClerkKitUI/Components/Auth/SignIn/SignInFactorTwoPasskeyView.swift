//
//  SignInFactorTwoPasskeyView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SignInFactorTwoPasskeyView: View {
  let factor: Factor

  var body: some View {
    SignInPasskeyView(factor: factor, isSecondFactor: true)
  }
}

#Preview {
  SignInFactorTwoPasskeyView(factor: .mockPasskey)
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
