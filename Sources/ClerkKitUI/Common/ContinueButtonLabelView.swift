//
//  ContinueButtonLabelView.swift
//

#if os(iOS)

import SwiftUI

struct ContinueButtonLabelView: View {
  @Environment(\.clerkTheme) private var theme
  let isActive: Bool = false

  var body: some View {
    HStack(spacing: 4) {
      Text("Continue", bundle: .module)
      Image("icon-triangle-right", bundle: .module)
        .foregroundStyle(theme.colors.primaryForeground)
        .opacity(0.6)
    }
    .frame(maxWidth: .infinity)
    .overlayProgressView(isActive: isActive) {
      SpinnerView(color: theme.colors.primaryForeground)
    }
  }
}

#endif
