//
//  SignInGetHelpView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SignInGetHelpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthState.self) private var authState

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Get help")
          HeaderView(style: .subtitle, text: "If you have trouble signing into your account, email us and we will work with you to restore access as soon as possible.")
        }
        .padding(.bottom, 32)

        VStack(spacing: 16) {
          Button {
            openEmail(to: clerk.environment.displayConfig?.supportEmail ?? "")
          } label: {
            Text("Email support", bundle: .module)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.primary())
          .simultaneousGesture(TapGesture())
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
  }
}

extension SignInGetHelpView {
  func openEmail(to emailAddress: String) {
    let urlString = "mailto:\(emailAddress)"

    if let url = URL(string: urlString) {
      UIApplication.shared.open(url)
    }
  }
}

#Preview {
  SignInGetHelpView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
