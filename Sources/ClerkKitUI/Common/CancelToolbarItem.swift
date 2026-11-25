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
      button
    }
  }

  @ViewBuilder
  private var button: some View {
    #if os(iOS)
    // Xcode 27.0 and 27.1 share a compiler version; gate the new SDK API separately.
    #if canImport(SwiftUI, _version: 8.0.85)
    if #available(iOS 27.1, *) {
      AxisAdaptiveCancelButton(action: action)
    } else {
      textButton
    }
    #else
    textButton
    #endif
    #else
    textButton
    #endif
  }

  private var textButton: some View {
    Button(action: action) {
      Text("Cancel", bundle: .module)
    }
    .foregroundStyle(theme.colors.primary)
  }
}

#if os(iOS) && canImport(SwiftUI, _version: 8.0.85)
@available(iOS 27.1, *)
private struct AxisAdaptiveCancelButton: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

  let action: () -> Void

  var body: some View {
    Button(action: action) {
      // The system keeps toolbar items without an icon out of the vertical bar.
      Label {
        Text("Cancel", bundle: .module)
      } icon: {
        Image(systemName: "xmark")
      }
      .labelStyle(IconInVerticalToolbarLabelStyle())
    }
    .foregroundStyle(theme.colors.primary)
    // The vertical bar colors items with the tint and ignores foregroundStyle.
    // There the X matches the system back and close buttons, which use the label color.
    .tint(toolbarVerticalEdge == nil ? nil : Color.primary)
    .accessibilityLabel(Text("Cancel", bundle: .module))
  }
}

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
