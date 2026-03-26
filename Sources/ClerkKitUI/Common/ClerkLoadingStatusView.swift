//
//  ClerkLoadingStatusView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct ClerkLoadingStatusView: View {
  @Environment(\.clerkTheme) private var theme

  let titleKey: LocalizedStringKey
  var spinnerColor: Color?

  init(_ titleKey: LocalizedStringKey, spinnerColor: Color? = nil) {
    self.titleKey = titleKey
    self.spinnerColor = spinnerColor
  }

  var body: some View {
    HStack(spacing: 8) {
      SpinnerView(color: spinnerColor ?? theme.colors.primary)
        .frame(width: 16, height: 16)

      Text(titleKey, bundle: .module)
        .font(theme.fonts.subheadline)
        .foregroundStyle(theme.colors.mutedForeground)
    }
  }
}

#Preview {
  VStack(spacing: 12) {
    ClerkLoadingStatusView("Loading authentication options…")
    ClerkLoadingStatusView("Verifying…", spinnerColor: .red)
  }
  .padding()
  .environment(\.clerkTheme, .clerk)
}

#endif
