#if os(iOS) || os(macOS)

import SwiftUI

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
  func spanningSideSafeAreas() -> some View {
    ignoresSafeArea(.container, edges: .horizontal)
  }
}

#endif
