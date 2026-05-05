//
//  ThreeDotsMenuLabel.swift
//

#if os(iOS)

import SwiftUI

struct ThreeDotsMenuLabel: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    Image("icon-three-dots-vertical", bundle: .module)
      .resizable()
      .scaledToFit()
      .foregroundColor(theme.colors.mutedForeground)
      .frame(width: 20, height: 20)
  }
}

#endif
