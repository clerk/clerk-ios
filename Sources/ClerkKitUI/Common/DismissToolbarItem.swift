#if os(iOS) || os(macOS)

import SwiftUI

struct DismissToolbarItem: ToolbarContent {
  private let action: (() -> Void)?

  init(action: (() -> Void)? = nil) {
    self.action = action
  }

  var body: some ToolbarContent {
    #if os(iOS)
    ToolbarItem(placement: .topBarTrailing) {
      DismissButton(action: action)
    }
    #elseif os(macOS)
    ToolbarItem(placement: .cancellationAction) {
      DismissButton(action: action)
    }
    #endif
  }
}

#endif
