//
//  OrganizationAccountListDataSource.swift
//

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationAccountListDataSource: OrganizationScopedContent {
  let scope: OrganizationUserScope
  let memberships: OrganizationPagedList<OrganizationMembership, Void>
  let invitations: OrganizationPagedList<UserOrganizationInvitation, Void>
  let suggestions: OrganizationPagedList<OrganizationSuggestion, Void>
  private(set) var creationDefaults: OrganizationCreationDefaults?
  var error: Error?
  private var isLoadingCreationDefaults: Bool
  @ObservationIgnored private var creationDefaultsTask: Task<Void, Never>?
  @ObservationIgnored private var isRetired = false

  var isLoading: Bool {
    memberships.isLoading || invitations.isLoading || suggestions.isLoading || isLoadingCreationDefaults
  }

  var hasExistingResources: Bool {
    !memberships.pager.items.isEmpty || !invitations.pager.items.isEmpty || !suggestions.pager.items.isEmpty
  }

  var hasFailedLists: Bool {
    (!memberships.isLoading && !memberships.hasLoaded)
      || (!invitations.isLoading && !invitations.hasLoaded)
      || (!suggestions.isLoading && !suggestions.hasLoaded)
  }

  var isLoadingMore: Bool {
    memberships.pager.isLoadingMore || invitations.pager.isLoadingMore || suggestions.pager.isLoadingMore
  }

  var hasNextPage: Bool {
    memberships.pager.hasNextPage || invitations.pager.hasNextPage || suggestions.pager.hasNextPage
  }

  init(scope: OrganizationUserScope, pageSize: Int = 10) {
    let user = scope.user
    self.scope = scope
    memberships = OrganizationPagedList(name: "memberships", isLoading: true) { _, offset in
      try await user.getOrganizationMemberships(offset: offset, pageSize: pageSize)
    }
    invitations = OrganizationPagedList(name: "invitations", isLoading: true) { _, offset in
      try await user.getOrganizationInvitations(offset: offset, pageSize: pageSize, status: ["pending"])
    }
    suggestions = OrganizationPagedList(name: "suggestions", isLoading: true) { _, offset in
      try await user.getOrganizationSuggestions(offset: offset, pageSize: pageSize, status: ["pending", "accepted"])
    }
    isLoadingCreationDefaults = scope.includesCreationDefaults

    let reportError: @MainActor (Error) -> Void = { [weak self] error in
      self?.error = error
    }
    memberships.onError = reportError
    invitations.onError = reportError
    suggestions.onError = reportError
  }

  func start() {
    reload()
  }

  func retire() {
    isRetired = true
    memberships.retire()
    invitations.retire()
    suggestions.retire()
    creationDefaultsTask?.cancel()
    creationDefaultsTask = nil
  }

  func reload() {
    guard !isRetired else { return }

    error = nil
    memberships.reload()
    invitations.reload()
    suggestions.reload()
    loadCreationDefaultsIfNeeded()
  }

  func acceptInvitation(_ invitation: UserOrganizationInvitation) async {
    do {
      try await invitations.mutate(invitation, as: .accepting) {
        try await .resolve(invitation.accept())
      }
    } catch {
      self.error = error
    }
  }

  func acceptSuggestion(_ suggestion: OrganizationSuggestion) async {
    do {
      try await suggestions.mutate(suggestion, as: .accepting) {
        try await .replace(suggestion.accept())
      }
    } catch {
      self.error = error
    }
  }

  private func loadCreationDefaultsIfNeeded() {
    guard scope.includesCreationDefaults, creationDefaults == nil, creationDefaultsTask == nil else { return }

    isLoadingCreationDefaults = true
    let user = scope.user
    creationDefaultsTask = Task { [weak self] in
      let defaults: OrganizationCreationDefaults?
      do {
        defaults = try await user.getOrganizationCreationDefaults()
      } catch {
        if !error.isCancellationError {
          ClerkLogger.error("Failed to fetch organization creation defaults", error: error)
        }
        defaults = nil
      }
      guard let self, !isRetired else { return }

      creationDefaults = defaults
      isLoadingCreationDefaults = false
      creationDefaultsTask = nil
    }
  }
}
