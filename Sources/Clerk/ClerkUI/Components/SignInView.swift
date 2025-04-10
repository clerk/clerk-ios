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
          .frame(width: 36, height: 36)
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
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .containerRelativeFrame([.vertical])
    }
  }
}

#Preview {
  let _ = Container.shared.setupMocks()
  SignInView()
    .environment(Clerk.shared)
    .environment(ClerkTheme.default)
}

#Preview("Custom Theme") {
  let _ = Container.shared.setupMocks()
  SignInView()
    .environment(Clerk.shared)
    .environment(
      \.clerkTheme,
       ClerkTheme(
        colors: .init(
          primary: Color(.red),
          text: .red,
          textSecondary: .black
        )
      )
    )
}

#Preview("Spanish") {
  let _ = Container.shared.setupMocks()
  SignInView()
    .environment(Clerk.shared)
    .environment(ClerkTheme.default)
    .environment(\.locale, .init(identifier: "es"))
}
