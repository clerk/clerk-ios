//
//  View+BottomTrackedFooter.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

extension View {
  func bottomTrackedFooter(
    isPresented: Bool,
    @ViewBuilder footer: @escaping (FooterSafeArea) -> some View
  ) -> some View {
    modifier(BottomTrackedFooterModifier(isPresented: isPresented, footer: footer))
  }
}

private struct BottomTrackedFooterModifier<Footer: View>: ViewModifier {
  @Environment(\.clerkFooterHostBottomInset) private var inheritedHostInset

  let isPresented: Bool
  let footer: (FooterSafeArea) -> Footer

  @State private var footerHeight: CGFloat = 0
  @State private var bottomSafeAreaInset: CGFloat = 0
  @State private var hostBottomSafeAreaInset: CGFloat = 0

  init(
    isPresented: Bool,
    @ViewBuilder footer: @escaping (FooterSafeArea) -> Footer
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

            footer(FooterSafeArea(
              containerInset: bottomSafeAreaInset,
              hostInset: inheritedHostInset ?? hostBottomSafeAreaInset
            ))
              .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
              } action: { newValue in
                footerHeight = newValue
              }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.safeAreaInsets.bottom
          } action: { newValue in
            bottomSafeAreaInset = newValue
          }
          #if os(iOS)
          .ignoresSafeArea(.keyboard, edges: .bottom)
          #endif
          .allowsHitTesting(false)
        }
      }
      #if os(iOS)
      .background {
        if isPresented, inheritedHostInset == nil {
          FooterHostSafeAreaReader { newValue in
            hostBottomSafeAreaInset = newValue
          }
          .ignoresSafeArea(.keyboard, edges: .bottom)
        }
      }
      #endif
  }
}

#endif
