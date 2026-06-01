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
  @State private var developmentModeHeight: CGFloat = 0

  let background: DevelopmentModeBackground

  func body(content: Content) -> some View {
    content
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if clerk.shouldShowDevelopmentModeWarning {
          Color.clear
            .frame(height: developmentModeHeight)
            .allowsHitTesting(false)
        }
      }
      .overlay {
        if clerk.shouldShowDevelopmentModeWarning {
          VStack(spacing: 0) {
            Spacer(minLength: 0)

            DevelopmentModeView()
              .padding(.top, 16)
              .frame(maxWidth: .infinity)
              .background {
                DevelopmentModeBackgroundView(background: background)
                  .ignoresSafeArea(.container, edges: .bottom)
              }
              .accessibilityElement(children: .combine)
              .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
              } action: { newValue in
                developmentModeHeight = newValue
              }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .ignoresSafeArea(.keyboard, edges: .bottom)
        }
      }
  }
}

#endif
