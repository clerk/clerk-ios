#if os(iOS) || os(macOS)

import SwiftUI

struct CancelToolbarItem: ToolbarContent {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  var body: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button {
        dismiss()
      } label: {
        Text("Cancel", bundle: .module)
      }
      .foregroundStyle(theme.colors.primary)
    }
  }
}

#endif
