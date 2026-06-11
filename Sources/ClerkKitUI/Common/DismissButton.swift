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
  private let accessibilityIdentifier: String
  private let action: (() -> Void)?

  init(
    accessibilityIdentifier: String = ClerkAccessibilityIdentifiers.dismissButton,
    action: (() -> Void)? = nil
  ) {
    self.accessibilityIdentifier = accessibilityIdentifier
    self.action = action
  }

  #if os(iOS)
  var secondaryPaletteStyle: AnyShapeStyle {
    if #available(iOS 26.0, *) {
      AnyShapeStyle(Color.clear)
    } else {
      AnyShapeStyle(Material.ultraThinMaterial)
    }
  }
  #endif

  var body: some View {
    Button {
      if let action {
        action()
      } else {
        dismiss()
      }
    } label: {
      #if os(iOS)
      Image(systemName: "xmark.circle.fill")
        .resizable()
        .scaledToFit()
        .symbolRenderingMode(.palette)
        .foregroundStyle(theme.colors.mutedForeground, secondaryPaletteStyle)
        .frame(width: 30, height: 30)
        .brightness(colorScheme == .light ? -0.05 : 0.05)
      #elseif os(macOS)
      Text("Close", bundle: .module)
        .foregroundStyle(theme.colors.primary)
      #endif
    }
    .accessibilityIdentifier(accessibilityIdentifier)
    .accessibilityLabel(Text("Close", bundle: .module))
  }
}

#Preview {
  DismissButton()
}

#endif
