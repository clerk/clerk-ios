//
//  SignInFactorOneCodeView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

import SwiftUI

struct SignInFactorOneCodeView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.authState) private var authState
  @State private var code = ""
  @State private var resendSeconds = 1
  
  var signIn: SignIn? {
    clerk.client?.signIn
  }
  
  var subtitleString: LocalizedStringKey {
    if let appName = clerk.environment.displayConfig?.applicationName {
      return "to continue to \(appName)"
    } else {
      return "to continue"
    }
  }
  
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Check your email")
          HeaderView(style: .subtitle, text: subtitleString)

          if let identifier = signIn?.identifier {
            Button {
              authState.step = .signInStart
            } label: {
              IdentityPreviewView(label: identifier)
            }
            .buttonStyle(.secondary(config: .init(size: .small)))
          }
        }
        .padding(.bottom, 32)
        
        VStack(spacing: 24) {
          OTPField(code: $code)
          
          AsyncButton {
            // resend
          } label: { isRunning in
            Text("Didn't recieve a code? Resend (\(resendSeconds))")
              .font(theme.fonts.subheadline)
          }
          .buttonStyle(.secondary(config: .init(emphasis: .none, size: .small)))
          
          Button {
            authState.step = .signInStart
          } label: {
            Text("Use another method")
              .font(theme.fonts.subheadline)
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
  SignInFactorOneCodeView()
    .environment(\.clerk, .mock)
}
