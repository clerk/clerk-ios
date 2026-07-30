//
//  EmbeddedNavigation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// Lets a host that embeds a Clerk component inside its own navigation
/// (e.g. Clerk's Expo SDK) supply the back affordance for the component's
/// root screen. The component keeps all of its own navigation chrome, so
/// titles, back buttons, gestures, and transitions stay native; only the
/// root back button is the host's, and tapping it runs this action.
@_spi(FrameworkIntegration)
@MainActor
public struct ClerkHostBackAction {
  private let handler: () -> Void

  public init(_ handler: @escaping () -> Void) {
    self.handler = handler
  }

  func callAsFunction() {
    handler()
  }
}

@_spi(FrameworkIntegration)
extension EnvironmentValues {
  /// The host's back action for an embedded component's root screen.
  /// `nil` (the default) leaves the component unchanged.
  @Entry public var clerkHostBackAction: ClerkHostBackAction?
}

private struct HostBackToolbarModifier: ViewModifier {
  @Environment(\.clerkHostBackAction) private var hostBackAction
  @Environment(\.clerkTheme) private var theme

  func body(content: Content) -> some View {
    #if os(iOS)
    if let hostBackAction {
      content.toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            hostBackAction()
          } label: {
            Image(systemName: "chevron.backward")
              .fontWeight(.semibold)
              // Match the system back button's label color rather than the tint.
              .foregroundStyle(theme.colors.foreground)
          }
          .accessibilityLabel(Text("Back"))
        }
      }
    } else {
      content
    }
    #else
    content
    #endif
  }
}

extension View {
  /// Shows the host's back button on an embedded component's root screen.
  func hostBackToolbar() -> some View {
    modifier(HostBackToolbarModifier())
  }
}

#endif
