//
//  OrganizationScope.swift
//

import ClerkKit
import Foundation

struct OrganizationScope: Equatable {
  let userID: String
  let organization: Organization
  let access: OrganizationAccess

  @MainActor
  init?(clerk: Clerk) {
    guard let user = clerk.user, let membership = clerk.organizationMembership else { return nil }

    self.init(
      userID: user.id,
      organization: membership.organization,
      access: OrganizationAccess(membership: membership, environment: clerk.environment)
    )
  }

  init(userID: String, organization: Organization, access: OrganizationAccess) {
    self.userID = userID
    self.organization = organization
    self.access = access
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.userID == rhs.userID && lhs.organization.id == rhs.organization.id && lhs.access == rhs.access
  }
}

struct OrganizationAccess: OptionSet, Hashable {
  let rawValue: Int

  static let readMemberships = Self(rawValue: 1 << 0)
  static let manageMemberships = Self(rawValue: 1 << 1)
  static let manageMembershipRequests = Self(rawValue: 1 << 2)
  static let readDomains = Self(rawValue: 1 << 3)
  static let manageDomains = Self(rawValue: 1 << 4)

  init(rawValue: Int) {
    self.rawValue = rawValue
  }

  init(membership: OrganizationMembership, environment: Clerk.Environment?) {
    var access: Self = []
    if membership.canReadMemberships {
      access.insert(.readMemberships)
    }
    if membership.canManageMemberships {
      access.insert(.manageMemberships)
      if environment?.organizationSettings.domains.enabled == true {
        access.insert(.manageMembershipRequests)
      }
    }
    if membership.canReadDomains {
      access.insert(.readDomains)
    }
    if membership.canManageDomains {
      access.insert(.manageDomains)
    }
    self = access
  }
}

struct OrganizationUserScope: Equatable {
  let user: User
  let includesCreationDefaults: Bool

  @MainActor
  init?(clerk: Clerk, includesCreationDefaults: Bool) {
    guard let user = clerk.user else { return nil }

    self.init(user: user, includesCreationDefaults: includesCreationDefaults)
  }

  init(user: User, includesCreationDefaults: Bool) {
    self.user = user
    self.includesCreationDefaults = includesCreationDefaults
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.user.id == rhs.user.id && lhs.includesCreationDefaults == rhs.includesCreationDefaults
  }
}
