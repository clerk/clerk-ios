//
//  UserProfileCustomItem.swift
//  Clerk
//

#if os(iOS)

import Foundation
import SwiftUI

/// A custom item displayed alongside Clerk's built-in rows in ``UserProfileView``.
public struct UserProfileCustomItem<Route: Hashable> {
  public let route: Route
  public let title: LocalizedStringKey
  public let icon: UserProfileRowIcon
  public let bundle: Bundle?
  public let placement: UserProfileCustomItemPlacement

  /// Creates a custom item for ``UserProfileView``.
  ///
  /// Items that share the same placement are displayed in the order they appear in the
  /// array passed to ``UserProfileView/userProfileItems(_:)``.
  ///
  /// - Parameters:
  ///   - route: The route that should be pushed when the item is tapped.
  ///   - title: The item title.
  ///   - icon: The icon displayed for the item.
  ///   - bundle: The bundle containing the icon and localized title. Defaults to the
  ///   current environment's resource lookup. Pass a bundle when the item's assets or
  ///   localizations live outside the host app's default bundle.
  ///   - placement: The insertion point relative to Clerk's built-in rows.
  public init(
    route: Route,
    title: LocalizedStringKey,
    icon: UserProfileRowIcon,
    bundle: Bundle? = nil,
    placement: UserProfileCustomItemPlacement = .sectionEnd(.profile)
  ) {
    self.route = route
    self.title = title
    self.icon = icon
    self.bundle = bundle
    self.placement = placement
  }
}

/// The icon displayed by a user profile row.
public enum UserProfileRowIcon: Hashable, Sendable {
  case asset(name: String)
  case system(name: String)
}

/// The placement of a custom item in ``UserProfileView``.
public enum UserProfileCustomItemPlacement: Sendable {
  case sectionStart(UserProfileSection)
  case sectionEnd(UserProfileSection)
  case before(UserProfileRow)
  case after(UserProfileRow)
}

/// A root-level section in ``UserProfileView``.
public enum UserProfileSection: Sendable {
  case profile
  case account
}

/// A built-in root-level row in ``UserProfileView``.
public enum UserProfileRow: Sendable {
  case manageAccount
  case security
  case switchAccount
  case addAccount
  case signOut
}

#endif
