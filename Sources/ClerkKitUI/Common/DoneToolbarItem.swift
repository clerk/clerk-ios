#if os(iOS) || os(macOS)

import SwiftUI

struct DoneToolbarItem: ToolbarContent {
  @Environment(\.clerkTheme) private var theme

  private let accessibilityIdentifier: String
  private let action: () -> Void

  init(accessibilityIdentifier: String, action: @escaping () -> Void) {
    self.accessibilityIdentifier = accessibilityIdentifier
    self.action = action
  }

  var body: some ToolbarContent {
    ToolbarItem(placement: placement) {
      Button(action: action) {
        VerticalToolbarLabel(title, systemImage: "checkmark")
      }
      .tintInVerticalToolbar(theme.colors.primary)
      .accessibilityIdentifier(accessibilityIdentifier)
    }
  }

  private var title: Text {
    let title = Text("Done", bundle: .module)
      .font(theme.fonts.body)
      .fontWeight(.semibold)
    #if os(iOS)
    return title.foregroundStyle(theme.colors.primary)
    #else
    return title
    #endif
  }

  private var placement: ToolbarItemPlacement {
    #if os(iOS)
    .topBarTrailing
    #else
    .confirmationAction
    #endif
  }
}

#endif
