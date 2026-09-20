#if os(iOS) || os(macOS)

import SwiftUI

private struct ContentSizedSheetModifier: ViewModifier {
  let additionalHeight: CGFloat?

  #if os(iOS)
  @State private var contentHeight: CGFloat?

  private var detents: Set<PresentationDetent> {
    guard let contentHeight, let additionalHeight else { return [.large] }
    // The system adds the bottom safe area to a custom detent's presentation height.
    return [.height(max(1, (contentHeight + additionalHeight).rounded(.up)))]
  }
  #endif

  func body(content: Content) -> some View {
    #if os(iOS)
    content
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.size.height
      } action: { contentHeight = $0 }
      .presentationDetents(detents)
    #else
    content
    #endif
  }
}

extension View {
  /// Fits the enclosing iOS sheet to this content, plus any measured height outside it.
  /// Apply to the inner content after padding, rather than to a scroll or navigation
  /// container. For navigation sheets, pass the scroll view's top safe-area inset;
  /// side navigation controls consume width instead. Pass `nil` until that measurement
  /// is available. The screen remains responsible for navigation, scrolling, and styling.
  func contentSizedSheet(additionalHeight: CGFloat? = 0) -> some View {
    modifier(ContentSizedSheetModifier(additionalHeight: additionalHeight))
  }
}

#endif
