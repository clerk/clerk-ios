//
//  UserProfileNavigation.swift
//  Clerk
//

#if os(iOS)

import Foundation
import SwiftUI

/// Manages presentation state for the user profile flow.
///
/// This class handles sheet presentation state for the user profile.
/// It is injected into child views via the environment.
@MainActor
@Observable
final class UserProfileSheetNavigation {
  /// Whether the account switcher sheet is presented.
  var accountSwitcherIsPresented = false

  /// Whether the auth view sheet is presented.
  var authViewIsPresented = false

  /// Whether the MFA type chooser sheet is presented.
  var chooseMfaTypeIsPresented = false

  /// The currently presented MFA add view type.
  var presentedAddMfaType: UserProfileAddMfaView.PresentedView?
}

/// Navigation API for navigating from custom rows to custom destinations inside
/// `UserProfileView`.
///
/// Custom destination views can read this value using:
///
/// ```swift
/// @Environment(UserProfileNavigator<MyRoute>.self) private var navigation
/// ```
@MainActor
@Observable
public final class UserProfileNavigator<Route: Hashable> {
  private let pushRow: @MainActor (Route) -> Void
  private let popToRootAction: @MainActor () -> Void

  init(
    push: @escaping @MainActor (Route) -> Void,
    popToRoot: @escaping @MainActor () -> Void
  ) {
    pushRow = push
    popToRootAction = popToRoot
  }

  public func push(_ route: Route) {
    pushRow(route)
  }

  /// Pops any pushed custom destinations and returns to the root screen of
  /// `UserProfileView`.
  public func popToRoot() {
    popToRootAction()
  }
}

enum UserProfileNavigationDestination<Route: Hashable>: Hashable {
  case builtIn(UserProfileRow)
  case custom(Route)
}

enum UserProfileDismissAction {
  case popToRoot
  case exitUserProfile
}

/// Internal built-in-only adapter for Clerk-owned child views that should not know about
/// the host app's custom `Route` type but still need to trigger profile navigation.
@MainActor
@Observable
final class UserProfileBuiltInRouter {
  private let pushRow: @MainActor (UserProfileRow) -> Void
  private let dismissAction: @MainActor (UserProfileDismissAction) -> Void

  init(
    push: @escaping @MainActor (UserProfileRow) -> Void,
    dismissAction: @escaping @MainActor (UserProfileDismissAction) -> Void
  ) {
    pushRow = push
    self.dismissAction = dismissAction
  }

  func push(_ row: UserProfileRow) {
    pushRow(row)
  }

  func dismiss(_ action: UserProfileDismissAction) {
    dismissAction(action)
  }
}

#endif
