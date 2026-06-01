//
//  View+BottomTrackedFooter.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

extension View {
  func bottomTrackedFooter(
    isPresented: Bool,
    @ViewBuilder footer: @escaping () -> some View
  ) -> some View {
    modifier(BottomTrackedFooterModifier(isPresented: isPresented, footer: footer))
  }
}

private struct BottomTrackedFooterModifier<Footer: View>: ViewModifier {
  let isPresented: Bool
  let footer: () -> Footer

  @State private var footerHeight: CGFloat = 0

  init(
    isPresented: Bool,
    @ViewBuilder footer: @escaping () -> Footer
  ) {
    self.isPresented = isPresented
    self.footer = footer
  }

  func body(content: Content) -> some View {
    content
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if isPresented {
          Color.clear
            .frame(height: footerHeight)
            .allowsHitTesting(false)
        }
      }
      .overlay {
        if isPresented {
          VStack(spacing: 0) {
            Spacer(minLength: 0)

            footer()
              .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
              } action: { newValue in
                footerHeight = newValue
              }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .ignoresSafeArea(.keyboard, edges: .bottom)
        }
      }
  }
}

#endif
