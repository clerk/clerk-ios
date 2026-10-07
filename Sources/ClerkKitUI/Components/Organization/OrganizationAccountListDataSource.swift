//
//  OrganizationAccountListDataSource.swift
//

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationAccountListDataSource: OrganizationPaginatedDataSource {
  let pageSize: Int

  var membershipsPager = OrganizationAccountListPager<OrganizationMembership>()
  var invitationsPager = OrganizationAccountListPager<UserOrganizationInvitation>()
  var suggestionsPager = OrganizationAccountListPager<OrganizationSuggestion>()
  var creationDefaults: OrganizationCreationDefaults?
  var isLoading = true
  var error: Error?

  var hasExistingResources: Bool {
    !membershipsPager.items.isEmpty || !invitationsPager.items.isEmpty || !suggestionsPager.items.isEmpty
  }

  var isLoadingMore: Bool {
    membershipsPager.isLoadingMore || invitationsPager.isLoadingMore || suggestionsPager.isLoadingMore
  }

  var hasNextPage: Bool {
    membershipsPager.hasNextPage || invitationsPager.hasNextPage || suggestionsPager.hasNextPage
  }

  init(pageSize: Int = 10) {
    self.pageSize = pageSize
  }

  func loadInitial(user: User?, includeCreationDefaults: Bool) async {
    guard let user else {
      isLoading = false
      return
    }
    guard !Task.isCancelled else { return }

    let requestIDs = [
      membershipsPager.startFirstPageLoad(),
      invitationsPager.startFirstPageLoad(),
      suggestionsPager.startFirstPageLoad(),
    ]
    isLoading = true
    error = nil

    do {
      async let fetchedMemberships = user.getOrganizationMemberships(page: 1, pageSize: pageSize)
      async let fetchedInvitations = user.getOrganizationInvitations(page: 1, pageSize: pageSize, status: ["pending"])
      async let fetchedSuggestions = user.getOrganizationSuggestions(page: 1, pageSize: pageSize, status: ["pending", "accepted"])
      async let fetchedDefaults = fetchCreationDefaults(user: user, isEnabled: includeCreationDefaults)

      let membershipsResult = try await fetchedMemberships
      let invitationsResult = try await fetchedInvitations
      let suggestionsResult = try await fetchedSuggestions
      let defaults = await fetchedDefaults

      if requestIDs == currentRequestIDs, !Task.isCancelled {
        membershipsPager.replace(with: membershipsResult)
        invitationsPager.replace(with: invitationsResult)
        suggestionsPager.replace(with: suggestionsResult)
        creationDefaults = defaults
      }
    } catch {
      if requestIDs == currentRequestIDs, !Task.isCancelled, !error.isCancellationError {
        self.error = error
      }
    }

    guard requestIDs == currentRequestIDs else { return }

    isLoading = false
    runDeferredLoadMore(user: user, requestIDs: requestIDs)
  }

  func loadMoreMemberships(user: User?) async {
    guard let user, !isLoadingMore else { return }

    await loadNextPage(\.membershipsPager, isLoading: \.isLoading, listName: "memberships") { [pageSize] offset in
      try await user.getOrganizationMemberships(offset: offset, pageSize: pageSize)
    }
  }

  func loadMoreInvitations(user: User?) async {
    guard let user, !isLoadingMore else { return }

    await loadNextPage(\.invitationsPager, isLoading: \.isLoading, listName: "invitations") { [pageSize] offset in
      try await user.getOrganizationInvitations(offset: offset, pageSize: pageSize, status: ["pending"])
    }
  }

  func loadMoreSuggestions(user: User?) async {
    guard let user, !isLoadingMore else { return }

    await loadNextPage(\.suggestionsPager, isLoading: \.isLoading, listName: "suggestions") { [pageSize] offset in
      try await user.getOrganizationSuggestions(offset: offset, pageSize: pageSize, status: ["pending", "accepted"])
    }
  }

  func acceptInvitation(_ invitation: UserOrganizationInvitation) async {
    do {
      let accepted = try await invitation.accept()
      invitationsPager.replace(accepted)
      invitationsPager.removeOneFromPagination()
    } catch {
      self.error = error
    }
  }

  func acceptSuggestion(_ suggestion: OrganizationSuggestion) async {
    do {
      let accepted = try await suggestion.accept()
      suggestionsPager.replace(accepted)
    } catch {
      self.error = error
    }
  }

  private var currentRequestIDs: [Int] {
    [membershipsPager.requestID, invitationsPager.requestID, suggestionsPager.requestID]
  }

  private func runDeferredLoadMore(user: User, requestIDs: [Int]) {
    let loadMemberships = membershipsPager.loadMoreIsDeferred
    let loadInvitations = invitationsPager.loadMoreIsDeferred
    let loadSuggestions = suggestionsPager.loadMoreIsDeferred
    guard loadMemberships || loadInvitations || loadSuggestions else { return }

    membershipsPager.loadMoreIsDeferred = false
    invitationsPager.loadMoreIsDeferred = false
    suggestionsPager.loadMoreIsDeferred = false
    Task { [weak self] in
      guard let self else { return }

      if loadMemberships, requestIDs == currentRequestIDs { await loadMoreMemberships(user: user) }
      if loadInvitations, requestIDs == currentRequestIDs { await loadMoreInvitations(user: user) }
      if loadSuggestions, requestIDs == currentRequestIDs { await loadMoreSuggestions(user: user) }
    }
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
