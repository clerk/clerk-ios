//
//  SignInGetHelpView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

import SwiftUI

struct SignInGetHelpView: View {
  @Environment(\.authState) private var authState
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Get help")
          HeaderView(style: .subtitle, text: "If you have trouble signing into your account, email us and we will work with you to restore access as soon as possible.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 16) {
          Button {
            //
          } label: {
            Text("Email support", bundle: .module)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.primary())
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
  }
}

#Preview {
  SignInGetHelpView()
}
