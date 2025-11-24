//
//  GetHelpView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct GetHelpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthState.self) private var authState

  let context: Context

  enum Context: Hashable {
    case signIn
    case signUp

    var subtitleText: LocalizedStringKey {
      switch self {
      case .signIn:
        "If you have trouble signing into your account, email us and we will work with you to restore access as soon as possible."
      case .signUp:
        "If you have trouble creating your account, email us and we will work with you to complete your registration as soon as possible."
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Get help")
          HeaderView(style: .subtitle, text: context.subtitleText)
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

extension GetHelpView {
  func openEmail(to emailAddress: String) {
    let urlString = "mailto:\(emailAddress)"

    if let url = URL(string: urlString) {
      UIApplication.shared.open(url)
    }
  }
}

#Preview("Sign In") {
  GetHelpView(context: .signIn)
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#Preview("Sign Up") {
  GetHelpView(context: .signUp)
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
