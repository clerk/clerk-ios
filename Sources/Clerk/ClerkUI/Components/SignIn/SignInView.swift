//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

import Factory
import SwiftUI

public struct SignInView: View {
  @State var state = SignInViewState()

  public init() {}

  public var body: some View {
    Group {
      state.flowStep.view
        .transition(.blurReplace.animation(.default))
    }
    .environment(\.signInViewState, state)
  }
}

#Preview {
  SignInView()
    .environment(\.clerk, .mock)
}
