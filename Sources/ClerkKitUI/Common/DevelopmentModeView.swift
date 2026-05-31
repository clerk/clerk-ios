//
//  DevelopmentModeView.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

struct DevelopmentModeView: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    Text("Development mode", bundle: .module)
      .font(theme.fonts.footnote.weight(.medium))
      .foregroundStyle(theme.colors.warning)
  }
}

#endif
