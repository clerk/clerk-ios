//
//  View+ContentSizingDetent.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

struct ContentSizingDetentModifier: ViewModifier {
  @State private var sheetHeight: CGFloat?

  private var detents: Set<PresentationDetent> {
    if let sheetHeight {
      [.height(sheetHeight)]
    } else {
      [.medium]
    }
  }

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.size.height
      } action: { newValue in
        sheetHeight = newValue
      }
      .presentationDetents(detents)
      .presentationDragIndicator(.visible)
  }
}

extension View {
  func contentSizingDetent() -> some View {
    modifier(ContentSizingDetentModifier())
  }
}

#endif
