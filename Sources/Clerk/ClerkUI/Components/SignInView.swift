//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

import Factory
import SwiftUI

public struct SignInView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var email: String = ""

  public init() {}

  private var signInText: Text {
    if let appName = clerk.environment.displayConfig?.applicationName {
      return Text("Sign in to \(appName)", bundle: .module)
    } else {
      return Text("Sign in", bundle: .module)
    }
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Image(systemName: "star.square.fill")
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: 36)
          .padding(.bottom, 24)
          .foregroundStyle(theme.colors.primary)

        signInText
          .font(theme.fonts.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .frame(minHeight: 32)
          .padding(.bottom, 8)
          .foregroundStyle(theme.colors.text)

        Text("Welcome back! Please sign in to continue", bundle: .module)
          .font(theme.fonts.subheadline)
          .multilineTextAlignment(.center)
          .frame(minHeight: 18)
          .foregroundStyle(theme.colors.textSecondary)
          .padding(.bottom, 24)

        ClerkTextField("Enter your email", text: $email)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 60)
    }
    .background(theme.colors.background)
  }
}

#Preview {
  let _ = Container.shared.setupMocks()
  SignInView()
    .environment(Clerk.shared)
}

#Preview("Clerk Theme") {
  let _ = Container.shared.setupMocks()
  SignInView()
    .environment(Clerk.shared)
    .environment(\.clerkTheme, .clerk)
}

#Preview("Spanish") {
  let _ = Container.shared.setupMocks()
  SignInView()
    .environment(Clerk.shared)
    .environment(\.locale, .init(identifier: "es"))
}
