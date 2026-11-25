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

/// Lets a host that embeds a dismissible Clerk component without presenting it
/// (e.g. Clerk's Expo SDK) learn that the component asked to be dismissed.
/// SwiftUI's `dismiss` does nothing for a view that is not presented, so the
/// host runs this action to remove the component itself.
@_spi(FrameworkIntegration)
@MainActor
public struct ClerkHostDismissAction {
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
  /// The host's dismiss action for an embedded dismissible component.
  /// `nil` (the default) leaves the component unchanged.
  @Entry public var clerkHostDismissAction: ClerkHostDismissAction?
}

private struct HostBackToolbarModifier: ViewModifier {
  @Environment(\.clerkHostBackAction) private var hostBackAction

  func body(content: Content) -> some View {
    if let hostBackAction {
      content.toolbar {
        #if os(iOS)
        // Xcode 27.0 and 27.1 share a compiler version; gate the new SDK API separately.
        #if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
          // The system keeps a plain-styled item out of the vertical bar unless it opts in.
          backToolbarItem(hostBackAction).axisBehavior(.verticalPreferred)
        } else {
          backToolbarItem(hostBackAction)
        }
        #else
        backToolbarItem(hostBackAction)
        #endif
        #else
        backToolbarItem(hostBackAction)
        #endif
      }
    } else {
      content
    }
  }

  private func backToolbarItem(_ hostBackAction: ClerkHostBackAction) -> some ToolbarContent {
    ToolbarItem(placement: hostBackToolbarPlacement) {
      Button {
        hostBackAction()
      } label: {
        Image(systemName: "chevron.backward")
          .fontWeight(.semibold)
      }
      // Opts out of the tint a toolbar button would otherwise take, so this
      // renders at the label color like the system back buttons alongside it.
      .buttonStyle(.plain)
      .accessibilityLabel(Text("Back", bundle: .module))
    }
  }

  private var hostBackToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS)
    .cancellationAction
    #else
    .navigation
    #endif
  }
}

extension View {
  func hostBackToolbar() -> some View {
    modifier(HostBackToolbarModifier())
  }
}

#endif
