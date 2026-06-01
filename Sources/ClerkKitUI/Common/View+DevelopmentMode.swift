//
//  View+DevelopmentMode.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

extension View {
  func developmentModeBottomInset(
    background: DevelopmentModeBackground = .white
  ) -> some View {
    modifier(DevelopmentModeBottomInsetModifier(background: background))
  }
}

private struct DevelopmentModeBottomInsetModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk

  let background: DevelopmentModeBackground

  func body(content: Content) -> some View {
    content
      .bottomTrackedFooter(isPresented: clerk.shouldShowDevelopmentModeWarning) {
        DevelopmentModeView()
          .padding(.top, 16)
          .frame(maxWidth: .infinity)
          .background {
            DevelopmentModeBackgroundView(background: background)
              .ignoresSafeArea(.container, edges: .bottom)
          }
      }
  }
}

#endif
