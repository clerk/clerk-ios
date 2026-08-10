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
        Text("Cancel", bundle: .module)
      }
      .foregroundStyle(theme.colors.primary)
    }
  }
}

#endif
