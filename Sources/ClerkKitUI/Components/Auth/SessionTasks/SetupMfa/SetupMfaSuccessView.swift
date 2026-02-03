//
//  SetupMfaSuccessView.swift
//  Clerk
//
//  Created by Clerk on 1/29/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SetupMfaSuccessView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  let mfaType: MfaType

  enum MfaType {
    case phoneCode
    case authenticatorApp

    var title: LocalizedStringKey {
      switch self {
      case .phoneCode:
        "SMS code verification enabled"
      case .authenticatorApp:
        "Authenticator app enabled"
      }
    }

    var message: LocalizedStringKey {
      switch self {
      case .phoneCode:
        "Two-step verification is now enabled. When signing in, you will need to enter a verification code sent to your phone number as an additional step."
      case .authenticatorApp:
        "Two-step verification is now enabled. When signing in, you will need to enter a verification code from your authenticator app as an additional step."
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 64))
          .foregroundStyle(theme.colors.success)
          .padding(.top, 32)

        VStack(spacing: 8) {
          Text(mfaType.title, bundle: .module)
            .font(theme.fonts.title)
            .foregroundStyle(theme.colors.foreground)

          Text(mfaType.message, bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .multilineTextAlignment(.center)
        }

        Button {
          finishSetup()
        } label: {
          HStack(spacing: 4) {
            Text("Continue", bundle: .module)
            Image("icon-triangle-right", bundle: .module)
              .foregroundStyle(theme.colors.primaryForeground)
              .opacity(0.6)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())

        SecuredByClerkView()
      }
      .padding(24)
    }
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
    .navigationBarBackButtonHidden()
  }

  func finishSetup() {
    // Dismiss the entire auth flow
    navigation.dismissAuthFlow?()
  }
}

#Preview {
  SetupMfaSuccessView(mfaType: .authenticatorApp)
    .environment(\.clerkTheme, .clerk)
}

#endif
