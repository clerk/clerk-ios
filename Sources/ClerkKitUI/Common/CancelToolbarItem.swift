#if os(iOS) || os(macOS)

import SwiftUI

struct CancelToolbarItem: ToolbarContent {
  @Environment(\.clerkTheme) private var theme

  private let action: () -> Void

  init(action: @escaping () -> Void) {
    self.action = action
  }

  var body: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button(action: action) {
        VerticalToolbarLabel(Text("Cancel", bundle: .module), systemImage: "xmark")
      }
      .foregroundStyle(theme.colors.primary)
      // As an X in the vertical bar, Cancel sits beside the system back and close
      // buttons, which use the label color.
      .tintInVerticalToolbar(.primary)
    }
  }
}

#endif
