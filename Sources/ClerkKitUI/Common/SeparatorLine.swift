#if os(iOS) || os(macOS)

import SwiftUI

/// A 1-point border that spans the side safe areas, as row backgrounds do,
/// so it reaches under a vertical toolbar on iPhone Duo.
struct SeparatorLine: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    Rectangle()
      .fill(theme.colors.border)
      .frame(height: 1)
      .spanningSideSafeAreas()
  }
}

extension View {
  /// Extends a full-width separator under the side safe areas, as row backgrounds do.
  func spanningSideSafeAreas() -> some View {
    ignoresSafeArea(.container, edges: .horizontal)
  }
}

#endif
