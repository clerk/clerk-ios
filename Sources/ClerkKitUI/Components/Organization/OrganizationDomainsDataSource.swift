//
//  OrganizationDomainsDataSource.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationDomainsDataSource: OrganizationScopedContent {
  let scope: OrganizationScope
  let list: OrganizationPagedList<OrganizationDomain, Void>
  var error: Error?

  private var canReadDomains: Bool {
    !scope.access.isDisjoint(with: [.readDomains, .manageDomains])
  }

  init(scope: OrganizationScope, pageSize: Int = 10) {
    let organization = scope.organization
    self.scope = scope
    list = OrganizationPagedList(
      name: "domains",
      isLoading: !scope.access.isDisjoint(with: [.readDomains, .manageDomains])
    ) { _, offset in
      try await organization.getDomains(offset: offset, pageSize: pageSize)
    }
    list.onError = { [weak self] error in
      self?.error = error
    }
  }

  func start() {
    guard canReadDomains else { return }
    list.reload()
  }

  func retire() {
    list.retire()
  }

  func domainChanged() {
    Task {
      await list.revalidate()
    }
  }

  func domainDeleted(_ domain: OrganizationDomain) async {
    try? await list.mutate(domain, as: .removing) { .remove(domain) }
  }
}

#endif
