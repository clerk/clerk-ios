//
//  UserProfileCustomRow.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

/// A custom row displayed alongside Clerk's built-in rows in ``UserProfileView``.
public struct UserProfileCustomRow<Route: Hashable> {
  let route: Route
  let title: LocalizedStringKey
  let icon: UserProfileRowIcon
  let placement: UserProfileCustomRowPlacement

  /// Creates a custom row for ``UserProfileView``.
  ///
  /// Rows that share the same placement are displayed in the order they appear in the
  /// array passed to ``UserProfileView/userProfileRows(_:)``.
  ///
  /// - Parameters:
  ///   - route: The route that should be pushed when the row is tapped.
  ///   - title: The row title.
  ///   - icon: The icon displayed for the row.
  ///   - placement: The insertion point relative to Clerk's built-in rows.
  public init(
    route: Route,
    title: LocalizedStringKey,
    icon: UserProfileRowIcon,
    placement: UserProfileCustomRowPlacement = .sectionEnd(.profile)
  ) {
    self.route = route
    self.title = title
    self.icon = icon
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
public enum UserProfileRow: Hashable, Sendable {
  case manageAccount
  case security
  case switchAccount
  case addAccount
  case signOut
}

// MARK: - Internal Helpers

extension UserProfileCustomRowPlacement {
  var section: UserProfileSection {
    switch self {
    case .sectionStart(let section):
      section
    case .sectionEnd(let section):
      section
    case .before(let row):
      row.section
    case .after(let row):
      row.section
    }
  }

  var isSectionStart: Bool {
    switch self {
    case .sectionStart:
      true
    default:
      false
    }
  }

  var isSectionEnd: Bool {
    switch self {
    case .sectionEnd:
      true
    default:
      false
    }
  }
}

extension UserProfileRow {
  var section: UserProfileSection {
    switch self {
    case .manageAccount, .security:
      .profile
    case .switchAccount, .addAccount, .signOut:
      .account
    }
  }

  var icon: String {
    switch self {
    case .manageAccount:
      "icon-profile"
    case .security:
      "icon-security"
    case .switchAccount:
      "icon-switch"
    case .addAccount:
      "icon-plus"
    case .signOut:
      "icon-sign-out"
    }
  }

  var title: LocalizedStringKey {
    switch self {
    case .manageAccount:
      "Manage account"
    case .security:
      "Security"
    case .switchAccount:
      "Switch account"
    case .addAccount:
      "Add account"
    case .signOut:
      "Sign out"
    }
  }
}

#endif
