//
//  UserProfileCustomRow.swift
//  Clerk
//

#if os(iOS)

import Foundation
import SwiftUI

/// A custom row displayed alongside Clerk's built-in rows in ``UserProfileView``.
public struct UserProfileCustomRow {
  public let id: AnyHashable
  public let title: LocalizedStringKey
  public let icon: UserProfileRowIcon
  public let bundle: Bundle?
  public let placement: UserProfileCustomRowPlacement

  /// Creates a custom row for ``UserProfileView``.
  ///
  /// Rows that share the same placement are displayed in the order they appear in the
  /// array passed to ``UserProfileView/init(isDismissable:navigationPath:customRows:)``.
  ///
  /// - Parameters:
  ///   - id: The route that should be pushed when the row is tapped.
  ///   - title: The row title.
  ///   - icon: The icon displayed for the row.
  ///   - bundle: The bundle containing the icon and localized title. Defaults to the
  ///   current environment's resource lookup. Pass a bundle when the row's assets or
  ///   localizations live outside the host app's default bundle.
  ///   - placement: The insertion point relative to Clerk's built-in rows.
  public init(
    id: some Hashable,
    title: LocalizedStringKey,
    icon: UserProfileRowIcon,
    bundle: Bundle? = nil,
    placement: UserProfileCustomRowPlacement = .sectionEnd(.profile)
  ) {
    self.id = AnyHashable(id)
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

/// The placement of a custom row in ``UserProfileView``.
public enum UserProfileCustomRowPlacement: Sendable {
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
