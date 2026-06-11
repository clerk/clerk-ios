//
//  OrganizationProfileCustomRow.swift
//

#if os(iOS) || os(macOS)

import SwiftUI

/// A custom row displayed alongside Clerk's built-in rows in ``OrganizationProfileView``.
public struct OrganizationProfileCustomRow<Route: Hashable> {
  let route: Route
  let title: LocalizedStringKey
  let icon: OrganizationProfileRowIcon
  let placement: OrganizationProfileCustomRowPlacement

  /// Creates a custom row for ``OrganizationProfileView``.
  ///
  /// Rows that share the same placement are displayed in the order they appear in the
  /// array passed to ``OrganizationProfileView/organizationProfileRows(_:)``.
  ///
  /// - Parameters:
  ///   - route: The route that should be pushed when the row is tapped.
  ///   - title: The row title.
  ///   - icon: The icon displayed for the row.
  ///   - placement: The insertion point relative to Clerk's built-in rows.
  public init(
    route: Route,
    title: LocalizedStringKey,
    icon: OrganizationProfileRowIcon,
    placement: OrganizationProfileCustomRowPlacement = .sectionEnd(.profile)
  ) {
    self.route = route
    self.title = title
    self.icon = icon
    self.placement = placement
  }

  /// Creates a custom row for ``OrganizationProfileView`` using a plain string title.
  ///
  /// Rows that share the same placement are displayed in the order they appear in the
  /// array passed to ``OrganizationProfileView/organizationProfileRows(_:)``.
  ///
  /// - Parameters:
  ///   - route: The route that should be pushed when the row is tapped.
  ///   - title: The row title.
  ///   - icon: The icon displayed for the row.
  ///   - placement: The insertion point relative to Clerk's built-in rows.
  public init(
    route: Route,
    title: String,
    icon: OrganizationProfileRowIcon,
    placement: OrganizationProfileCustomRowPlacement = .sectionEnd(.profile)
  ) {
    self.init(
      route: route,
      title: LocalizedStringKey(title),
      icon: icon,
      placement: placement
    )
  }
}

/// The icon displayed by an organization profile row.
public typealias OrganizationProfileRowIcon = UserProfileRowIcon

/// The placement of a custom row in ``OrganizationProfileView``.
public enum OrganizationProfileCustomRowPlacement: Sendable {
  case sectionStart(OrganizationProfileSection)
  case sectionEnd(OrganizationProfileSection)
  case before(OrganizationProfileRow)
  case after(OrganizationProfileRow)
}

/// A root-level section in ``OrganizationProfileView``.
public enum OrganizationProfileSection: Sendable {
  case profile
  case actions
}

/// A built-in root-level row in ``OrganizationProfileView``.
public enum OrganizationProfileRow: Hashable, Sendable {
  case members
  case verifiedDomains
  case leaveOrganization
  case deleteOrganization
}

// MARK: - Internal Helpers

extension OrganizationProfileCustomRowPlacement {
  var section: OrganizationProfileSection {
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

extension OrganizationProfileRow {
  var section: OrganizationProfileSection {
    switch self {
    case .members, .verifiedDomains:
      .profile
    case .leaveOrganization, .deleteOrganization:
      .actions
    }
  }

  var icon: OrganizationProfileRowIcon {
    switch self {
    case .members:
      .system(name: "person.2.fill")
    case .verifiedDomains:
      .asset(name: "icon-security")
    case .leaveOrganization, .deleteOrganization:
      .asset(name: "icon-sign-out")
    }
  }

  var title: LocalizedStringKey {
    switch self {
    case .members:
      "Members"
    case .verifiedDomains:
      "Verified domains"
    case .leaveOrganization:
      "Leave organization"
    case .deleteOrganization:
      "Delete organization"
    }
  }
}

#endif
