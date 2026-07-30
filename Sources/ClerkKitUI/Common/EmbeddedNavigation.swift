//
//  EmbeddedNavigation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// Lets a host app that embeds Clerk components inside its own navigation chrome
/// (e.g. Clerk's Expo SDK) hide Clerk's navigation bars while observing and driving
/// the component's internal navigation stack.
///
/// Setting an instance in the environment via `\.clerkEmbeddedNavigation` hides the
/// navigation bars of `UserProfileView` and `AuthView` (iOS only), and the component
/// reports depth changes through ``onDepthChange`` and executes ``pop()`` /
/// ``popToRoot()`` on its internal stack. When the environment value is `nil`
/// (the default), component behavior is unchanged.
///
/// Only one embedded component drives an instance at a time; the most recently
/// appeared component wins.
@_spi(FrameworkIntegration)
@MainActor
public final class ClerkEmbeddedNavigation {
  /// Called with the number of screens pushed above the embedded component's root
  /// whenever its internal navigation stack changes.
  public var onDepthChange: ((Int) -> Void)?

  /// Whether the component hides its own navigation bars. `true` (the default)
  /// is for hosts that draw their own header. When `false`, the component keeps
  /// its native chrome — bars, titles, back buttons, and transitions — and the
  /// host only supplies the root back affordance via ``hostBackAction``.
  public var hidesNavigationBars = true

  /// Invoked when the user taps the back button on the embedded component's
  /// root screen; the host should pop its own navigation. A back button is
  /// shown at the root only while this is non-`nil` and bars are kept.
  public var hostBackAction: (() -> Void)?

  /// Identifies one component's registration so a superseded or disappearing
  /// component can neither drive the host nor tear down its successor.
  @MainActor
  final class Registration {
    fileprivate let popHandler: (_ toRoot: Bool) -> Void

    fileprivate init(popHandler: @escaping (_ toRoot: Bool) -> Void) {
      self.popHandler = popHandler
    }
  }

  private var current: Registration?

  public init() {}

  /// Pops one screen off the embedded component's internal stack. No-op at the root.
  public func pop() {
    current?.popHandler(false)
  }

  /// Pops the embedded component's internal stack back to its root screen.
  public func popToRoot() {
    current?.popHandler(true)
  }

  /// Registers the embedded component driving this coordinator. The most recent
  /// registration wins; commands and depth reports from earlier registrations
  /// are ignored.
  func register(popHandler: @escaping (_ toRoot: Bool) -> Void) -> Registration {
    let registration = Registration(popHandler: popHandler)
    current = registration
    return registration
  }

  /// No-op unless `registration` is still current, so a disappearing component
  /// cannot tear down a successor that registered before it went away.
  func unregister(_ registration: Registration) {
    guard current === registration else { return }
    current = nil
  }

  func reportDepth(_ depth: Int, from registration: Registration) {
    guard current === registration else { return }
    onDepthChange?(depth)
  }
}

@_spi(FrameworkIntegration)
extension EnvironmentValues {
  /// Embedded-navigation coordinator for embedding Clerk components headerless inside
  /// a host-owned navigation UI. `nil` (the default) leaves Clerk's built-in
  /// navigation chrome untouched.
  @Entry public var clerkEmbeddedNavigation: ClerkEmbeddedNavigation?
}

private struct EmbeddedNavigationBarHiddenModifier: ViewModifier {
  @Environment(\.clerkEmbeddedNavigation) private var embeddedNavigation

  func body(content: Content) -> some View {
    #if os(iOS)
    if let embeddedNavigation, embeddedNavigation.hidesNavigationBars {
      content.toolbar(.hidden, for: .navigationBar)
    } else {
      content
    }
    #else
    content
    #endif
  }
}

extension View {
  /// Hides the navigation bar when embedded navigation is active (iOS only).
  func embeddedNavigationBarHidden() -> some View {
    modifier(EmbeddedNavigationBarHiddenModifier())
  }
}

private struct EmbeddedHostBackToolbarModifier: ViewModifier {
  @Environment(\.clerkEmbeddedNavigation) private var embeddedNavigation

  func body(content: Content) -> some View {
    #if os(iOS)
    if let embeddedNavigation, !embeddedNavigation.hidesNavigationBars,
       let hostBackAction = embeddedNavigation.hostBackAction
    {
      content.toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            hostBackAction()
          } label: {
            Image(systemName: "chevron.backward")
              .fontWeight(.semibold)
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
  /// Shows the host's back button on the embedded component's root screen when
  /// the host keeps Clerk's navigation chrome (iOS only).
  func embeddedHostBackToolbar() -> some View {
    modifier(EmbeddedHostBackToolbarModifier())
  }
}

#endif
