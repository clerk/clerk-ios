//
//  DismissButton.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct DismissButton: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  var accessibilityIdentifier: String
  var action: (() -> Void)?

  init(
    accessibilityIdentifier: String = ClerkAccessibilityIdentifiers.dismissButton,
    action: (() -> Void)? = nil
  ) {
    self.accessibilityIdentifier = accessibilityIdentifier
    self.action = action
  }

  var secondaryPaletteStyle: AnyShapeStyle {
    #if os(iOS)
    if #available(iOS 26.0, *) {
      AnyShapeStyle(Color.clear)
    } else {
      AnyShapeStyle(Material.ultraThinMaterial)
    }
    #else
    AnyShapeStyle(Material.ultraThinMaterial)
    #endif
  }

  var body: some View {
    Button {
      if let action {
        action()
      } else {
        dismiss()
      }
    } label: {
      Image(systemName: "xmark.circle.fill")
        .resizable()
        .scaledToFit()
        .symbolRenderingMode(.palette)
        .foregroundStyle(theme.colors.mutedForeground, secondaryPaletteStyle)
        .frame(width: 30, height: 30)
        .brightness(colorScheme == .light ? -0.05 : 0.05)
    }
    .accessibilityIdentifier(accessibilityIdentifier)
    .accessibilityLabel(Text("Close", bundle: .module))
  }
}

#Preview {
  DismissButton()
}

#endif
