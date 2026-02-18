//
//  UserProfileNavigation.swift
//  Clerk
//

#if os(iOS)

import Foundation
import SwiftUI

/// Manages navigation and presentation state for the user profile flow.
///
/// This class handles navigation path management and sheet presentation state.
/// It is injected into child views via the environment.
@MainActor
@Observable
final class UserProfileNavigation {
  /// The internal navigation path for standalone `UserProfileView` usage.
  var path = NavigationPath()
  
  /// Whether the account switcher sheet is presented.
  var accountSwitcherIsPresented = false
  
  /// Whether the auth view sheet is presented.
  var authViewIsPresented = false
  
  /// Whether the MFA type chooser sheet is presented.
  var chooseMfaTypeIsPresented = false
  
  /// The currently presented MFA add view type.
  var presentedAddMfaType: UserProfileAddMfaView.PresentedView?
  
  /// Creates a new UserProfileNavigation instance.
  init() {}
}

/// Routing API for navigating inside `UserProfileView` and nested destinations.
struct UserProfileRouter: Sendable {
  let push: @MainActor @Sendable (UserProfileView.Destination) -> Void
  let popToRoot: @MainActor @Sendable (_ includingSelf: Bool) -> Void
}

private struct UserProfileRouterKey: EnvironmentKey {
  static let defaultValue = UserProfileRouter(
    push: { _ in },
    popToRoot: { _ in }
  )
}

extension EnvironmentValues {
  var userProfileRouter: UserProfileRouter {
    get { self[UserProfileRouterKey.self] }
    set { self[UserProfileRouterKey.self] = newValue }
  }
}

#endif
