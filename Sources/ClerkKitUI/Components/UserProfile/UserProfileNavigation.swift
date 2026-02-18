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
  /// The navigation path for the user profile flow (used when managing own NavigationStack).
  var path = NavigationPath()
  
  /// An external navigation path binding provided by the parent.
  /// When set, navigation pushes are forwarded to the parent's path instead of the internal one.
  private(set) var externalPath: Binding<NavigationPath>?
  
  /// The count of the external path when UserProfileView first appeared.
  /// Used to determine how many entries we pushed so `popToRoot()` only removes ours.
  private var externalPathBaseCount: Int?
  
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
  
  /// Configures the navigation to use an external path from a parent `NavigationStack`.
  /// When configured, navigation pushes are forwarded to the parent's path.
  func configure(externalPath: Binding<NavigationPath>) {
    self.externalPath = externalPath
    self.externalPathBaseCount = externalPath.wrappedValue.count
  }
  
  /// Navigates to the specified destination.
  ///
  /// When an external navigation path is provided (embedded mode), pushes onto the parent's path.
  /// Otherwise, pushes onto the internal path (standalone mode).
  func navigate(to destination: UserProfileView.Destination) {
    if let externalPath {
      externalPath.wrappedValue.append(destination)
    } else {
      path.append(destination)
    }
  }
  
  /// Pops to the root of the user profile flow.
  ///
  /// In standalone mode, resets the internal navigation path.
  /// In embedded mode, removes only the entries pushed by the user profile flow,
  /// leaving the parent's pre-existing entries intact.
  ///
  /// - Parameter includingSelf: When `true`, also removes the entry that pushed
  ///   `UserProfileView` itself onto the parent's path. Use this when the user
  ///   has been deleted and there are no remaining sessions to display.
  func popToRoot(includingSelf: Bool = false) {
    if let externalPath, let baseCount = externalPathBaseCount {
      let adjustedBase = max(includingSelf ? baseCount - 1 : baseCount, 0)
      let currentCount = externalPath.wrappedValue.count
      let entriesToRemove = min(max(currentCount - adjustedBase, 0), currentCount)
      if entriesToRemove > 0 {
        externalPath.wrappedValue.removeLast(entriesToRemove)
      }
    } else {
      path = NavigationPath()
    }
  }
}

#endif
