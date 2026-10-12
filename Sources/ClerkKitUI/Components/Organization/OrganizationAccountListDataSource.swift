//
//  OrganizationAccountListDataSource.swift
//

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationAccountListDataSource {
  let pageSize: Int

  let memberships = OrganizationPagedList<OrganizationMembership>(name: "memberships")
  let invitations = OrganizationPagedList<UserOrganizationInvitation>(name: "invitations")
  let suggestions = OrganizationPagedList<OrganizationSuggestion>(name: "suggestions")
  var creationDefaults: OrganizationCreationDefaults?
  var error: Error?
  private var isLoadingCreationDefaults = false
  @ObservationIgnored private var loadID = 0
  @ObservationIgnored private(set) var loadedUserID: String?

  var isLoading: Bool {
    memberships.isLoading || invitations.isLoading || suggestions.isLoading || isLoadingCreationDefaults
  }

  var hasExistingResources: Bool {
    !memberships.pager.items.isEmpty || !invitations.pager.items.isEmpty || !suggestions.pager.items.isEmpty
  }

  /// Whether a list's latest load failed, leaving it missing while the others show.
  var hasFailedLists: Bool {
    guard loadedUserID != nil else { return false }

    return (!memberships.isLoading && !memberships.hasLoaded)
      || (!invitations.isLoading && !invitations.hasLoaded)
      || (!suggestions.isLoading && !suggestions.hasLoaded)
  }

  var isLoadingMore: Bool {
    memberships.pager.isLoadingMore || invitations.pager.isLoadingMore || suggestions.pager.isLoadingMore
  }

  var hasNextPage: Bool {
    memberships.pager.hasNextPage || invitations.pager.hasNextPage || suggestions.pager.hasNextPage
  }

  init(pageSize: Int = 10) {
    self.pageSize = pageSize
    let reportError: @MainActor (Error) -> Void = { [weak self] error in
      self?.error = error
    }
    memberships.onError = reportError
    invitations.onError = reportError
    suggestions.onError = reportError
  }

  func loadInitial(user: User?, includeCreationDefaults: Bool) async {
    loadID += 1
    let loadID = loadID
    guard let user else {
      loadedUserID = nil
      resetLists(isLoading: false)
      return
    }
    if user.id != loadedUserID {
      loadedUserID = user.id
      resetLists(isLoading: true)
    }

    error = nil
    isLoadingCreationDefaults = true
    async let fetchedDefaults = fetchCreationDefaults(user: user, isEnabled: includeCreationDefaults)
    let loads = [
      memberships.reload { [pageSize] offset in
        try await user.getOrganizationMemberships(offset: offset, pageSize: pageSize)
      },
      invitations.reload { [pageSize] offset in
        try await user.getOrganizationInvitations(offset: offset, pageSize: pageSize, status: ["pending"])
      },
      suggestions.reload { [pageSize] offset in
        try await user.getOrganizationSuggestions(offset: offset, pageSize: pageSize, status: ["pending", "accepted"])
      },
    ]
    for load in loads {
      await load.value
    }
    let defaults = await fetchedDefaults
    guard loadID == self.loadID else { return }

    creationDefaults = defaults
    isLoadingCreationDefaults = false
  }

  func acceptInvitation(_ invitation: UserOrganizationInvitation) async {
    do {
      let accepted = try await invitation.accept()
      invitations.update {
        $0.replace(accepted)
        $0.removeOneFromPagination()
      }
    } catch {
      self.error = error
    }
  }

  func acceptSuggestion(_ suggestion: OrganizationSuggestion) async {
    do {
      let accepted = try await suggestion.accept()
      suggestions.update { $0.replace(accepted) }
    } catch {
      self.error = error
    }
  }

  private func resetLists(isLoading: Bool) {
    memberships.reset(isLoading: isLoading)
    invitations.reset(isLoading: isLoading)
    suggestions.reset(isLoading: isLoading)
    creationDefaults = nil
    isLoadingCreationDefaults = false
  }

  private func fetchCreationDefaults(user: User, isEnabled: Bool) async -> OrganizationCreationDefaults? {
    guard isEnabled else { return nil }

    do {
      return try await user.getOrganizationCreationDefaults()
    } catch {
      ClerkLogger.error("Failed to fetch organization creation defaults", error: error)
      return nil
    }
  }
}
