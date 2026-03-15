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

  /// Creates a new UserProfileSheetNavigation instance.
  init() {}
}

/// Routing API for navigating inside `UserProfileView` and nested destinations.
struct UserProfileRouter {
  let push: @MainActor @Sendable (UserProfileDestination) -> Void
  let popToRoot: @MainActor @Sendable (_ includingSelf: Bool) -> Void

  @MainActor
  func push(_ row: UserProfileRow) {
    push(.builtIn(row))
  }

  @MainActor
  func push(_ route: some Hashable) {
    push(.custom(AnyHashable(route)))
  }
}

extension EnvironmentValues {
  @Entry var userProfileRouter = UserProfileRouter(
    push: { _ in },
    popToRoot: { _ in }
  )
}

#endif
