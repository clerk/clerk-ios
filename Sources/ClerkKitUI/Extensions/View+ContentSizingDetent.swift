//
//  View+ContentSizingDetent.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct ContentSizingDetentModifier: ViewModifier {
  #if os(iOS)
  @State private var sheetHeight: CGFloat?

  private var detents: Set<PresentationDetent> {
    if let sheetHeight {
      [.height(sheetHeight)]
    } else {
      [.medium]
    }
  }
  #endif

  func body(content: Content) -> some View {
    #if os(iOS)
    content
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.size.height
      } action: { newValue in
        sheetHeight = newValue
      }
      .presentationDetents(detents)
      .presentationDragIndicator(.visible)
    #elseif os(macOS)
    content
    #endif
  }
}

extension View {
  func contentSizingDetent() -> some View {
    modifier(ContentSizingDetentModifier())
  }
}

#endif
