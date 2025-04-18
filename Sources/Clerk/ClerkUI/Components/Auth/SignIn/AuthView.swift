//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

import Factory
import SwiftUI

public struct AuthView: View {
  @Environment(\.clerkTheme) private var theme
  @State var authState = AuthState()

  public init() {}

  public var body: some View {
    Group {
      authState.flowStep.view
        .transition(.blurReplace.animation(.default))
    }
    .background(theme.colors.background)
    .environment(\.authState, authState)
  }
}

#Preview {
  AuthView()
    .environment(\.clerk, .mock)
}
