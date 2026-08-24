//
//  SignInClientTrustWarningView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct SignInClientTrustWarningView: View {
  var body: some View {
    WarningText(
      "You're signing in from a new device. We're asking for verification to keep your account secure.",
      bundle: .module
    )
  }
}

#endif
