//
//  SignInFactorOneView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

import SwiftUI

struct SignInFactorOneView: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    SignInFactorOnePasswordView()
  }
}

#Preview {
  SignInFactorOneView()
}
