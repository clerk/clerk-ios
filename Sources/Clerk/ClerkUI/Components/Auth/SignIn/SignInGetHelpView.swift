//
//  SignInGetHelpView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

import SwiftUI

struct SignInGetHelpView: View {
  @Environment(\.authState) private var authState

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

          Button {
            authState.step = .signInStart
          } label: {
            Text("Back", bundle: .module)
          }
          .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(.vertical, 32)
      .padding(.horizontal, 16)
    }
  }
}

#Preview {
  SignInGetHelpView()
}
