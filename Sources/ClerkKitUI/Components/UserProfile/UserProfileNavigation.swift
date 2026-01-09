//
//  UserProfileNavigation.swift
//  Clerk
//
//  Created by Claude on 1/9/26.
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
public final class UserProfileNavigation {
  /// The navigation path for the user profile flow.
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
  public init() {}
}

#endif
