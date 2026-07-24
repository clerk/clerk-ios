//
//  HostedNavigation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// Lets a host app that embeds Clerk components inside its own navigation chrome
/// (e.g. Clerk's Expo SDK) hide Clerk's navigation bars while observing and driving
/// the component's internal navigation stack.
///
/// Setting an instance in the environment via `\.clerkHostedNavigation` hides the
/// navigation bars of `UserProfileView` and `AuthView` (iOS only). When the
/// environment value is `nil` (the default), component behavior is unchanged.
///
/// `UserProfileView` hosts should prefer the public `navigationPath:` initializer and
/// own the stack directly — hiding is the only effect this environment value has on it.
/// `AuthView` owns an internal stack, so it additionally reports depth changes through
/// ``onDepthChange`` and executes ``pop()`` / ``popToRoot()``.
///
/// Only one embedded component drives an instance at a time; the most recently
/// appeared component wins.
@_spi(FrameworkIntegration)
@MainActor
public final class ClerkHostedNavigation {
  /// Called with the number of screens pushed above the embedded component's root
  /// whenever its internal navigation stack changes.
  public var onDepthChange: ((Int) -> Void)?

  private var popHandler: ((_ toRoot: Bool) -> Void)?

  public init() {}

  /// Pops one screen off the embedded component's internal stack. No-op at the root.
  public func pop() {
    popHandler?(false)
  }

  /// Pops the embedded component's internal stack back to its root screen.
  public func popToRoot() {
    popHandler?(true)
  }

  func register(popHandler: @escaping (_ toRoot: Bool) -> Void) {
    self.popHandler = popHandler
  }

  func unregister() {
    popHandler = nil
  }

  func reportDepth(_ depth: Int) {
    onDepthChange?(depth)
  }
}

@_spi(FrameworkIntegration)
extension EnvironmentValues {
  /// Hosted-navigation coordinator for embedding Clerk components headerless inside
  /// a host-owned navigation UI. `nil` (the default) leaves Clerk's built-in
  /// navigation chrome untouched.
  @Entry public var clerkHostedNavigation: ClerkHostedNavigation?
}

private struct HostedNavigationBarHiddenModifier: ViewModifier {
  @Environment(\.clerkHostedNavigation) private var hostedNavigation

  func body(content: Content) -> some View {
    #if os(iOS)
    if hostedNavigation != nil {
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
  /// Hides the navigation bar when hosted navigation is active (iOS only).
  func hostedNavigationBarHidden() -> some View {
    modifier(HostedNavigationBarHiddenModifier())
  }
}

#endif
