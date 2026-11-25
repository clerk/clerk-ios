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
        label
      }
      .foregroundStyle(theme.colors.primary)
      // The vertical bar ignores foregroundStyle and colors items with the tint.
      .tint(theme.colors.primary)
      .accessibilityLabel(Text("Cancel", bundle: .module))
    }
  }

  @ViewBuilder
  private var label: some View {
    #if os(iOS)
    // Xcode 27.0 and 27.1 share a compiler version; gate the new SDK API separately.
    #if canImport(SwiftUI, _version: 8.0.85)
    if #available(iOS 27.1, *) {
      // The system keeps toolbar items without an icon out of the vertical bar.
      Label {
        Text("Cancel", bundle: .module)
      } icon: {
        Image(systemName: "xmark")
      }
      .labelStyle(IconInVerticalToolbarLabelStyle())
    } else {
      Text("Cancel", bundle: .module)
    }
    #else
    Text("Cancel", bundle: .module)
    #endif
    #else
    Text("Cancel", bundle: .module)
    #endif
  }
}

#if os(iOS) && canImport(SwiftUI, _version: 8.0.85)
@available(iOS 27.1, *)
private struct IconInVerticalToolbarLabelStyle: LabelStyle {
  @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

  func makeBody(configuration: Configuration) -> some View {
    if toolbarVerticalEdge == nil {
      configuration.title
    } else {
      configuration.icon
    }
  }
}
#endif

#endif
