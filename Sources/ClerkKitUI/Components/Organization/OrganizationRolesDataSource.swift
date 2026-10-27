//
//  OrganizationRolesDataSource.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationRolesDataSource: OrganizationScopedContent {
  private static let pageSize = 20

  let scope: OrganizationScope
  let list: OrganizationPagedList<RoleResource, Void>
  var error: Error?

  var roles: [RoleResource] {
    list.pager.items
  }

  var hasRoleSetMigration: Bool {
    list.pager.hasRoleSetMigration
  }

  var isLoading: Bool {
    list.isLoading
  }

  init(scope: OrganizationScope) {
    let organization = scope.organization
    self.scope = scope
    list = OrganizationPagedList(name: "roles", isLoading: true) { _, _ in
      let first = try await organization.getRoles(page: 1, pageSize: Self.pageSize)
      var roles = first.data
      var page = 1
      while roles.count < first.totalCount {
        page += 1
        let next = try await organization.getRoles(page: page, pageSize: Self.pageSize)
        guard !next.data.isEmpty else { break }
        roles += next.data
      }
      return ClerkPaginatedResponse(data: roles, totalCount: roles.count, hasRoleSetMigration: first.hasRoleSetMigration)
    }
    list.onError = { [weak self] error in
      self?.error = error
    }
  }

  func start() {
    list.reload()
  }

  func retire() {
    list.retire()
  }

  func refresh() async {
    await list.refresh()
  }
}

#endif
