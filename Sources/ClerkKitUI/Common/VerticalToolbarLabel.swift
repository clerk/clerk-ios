#if os(iOS) || os(macOS)

import SwiftUI

struct VerticalToolbarLabel: View {
  private let title: Text
  private let systemImage: String

  init(_ title: Text, systemImage: String) {
    self.title = title
    self.systemImage = systemImage
  }

  var body: some View {
    #if os(iOS)
    // Xcode 27.0 and 27.1 share a compiler version; gate the new SDK API separately.
    #if canImport(SwiftUI, _version: 8.0.85)
    if #available(iOS 27.1, *) {
      // The system keeps toolbar items without an icon out of the vertical bar.
      Label {
        title
      } icon: {
        Image(systemName: systemImage)
      }
      .labelStyle(IconInVerticalToolbarLabelStyle())
      .accessibilityLabel(title)
    } else {
      title
    }
    #else
    title
    #endif
    #else
    title
    #endif
  }
}

extension View {
  func tintInVerticalToolbar(_ color: Color) -> some View {
    modifier(VerticalToolbarTint(color: color))
  }
}

private struct VerticalToolbarTint: ViewModifier {
  let color: Color

  func body(content: Content) -> some View {
    #if os(iOS) && canImport(SwiftUI, _version: 8.0.85)
    if #available(iOS 27.1, *) {
      content.modifier(VerticalEdgeTint(color: color))
    } else {
      content
    }
    #else
    content
    #endif
  }
}

#if os(iOS) && canImport(SwiftUI, _version: 8.0.85)
@available(iOS 27.1, *)
private struct VerticalEdgeTint: ViewModifier {
  @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

  let color: Color

  func body(content: Content) -> some View {
    // The vertical bar colors items with the tint and ignores foregroundStyle.
    content.tint(toolbarVerticalEdge == nil ? nil : color)
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
