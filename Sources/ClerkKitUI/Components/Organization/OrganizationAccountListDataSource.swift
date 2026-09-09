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

    isLoading = true
    defer { isLoading = false }

    error = nil

    do {
      async let fetchedMemberships = user.getOrganizationMemberships(.init(initialPage: 1, pageSize: Double(pageSize)))
      async let fetchedInvitations = user.getOrganizationInvitations(.init(initialPage: 1, pageSize: Double(pageSize), status: .pending))
      async let fetchedSuggestions = user.getOrganizationSuggestions(.init(initialPage: 1, pageSize: Double(pageSize), status: .case3([.pending, .accepted])))
      async let fetchedDefaults = fetchCreationDefaults(user: user, isEnabled: includeCreationDefaults)

      let membershipsResult = try await fetchedMemberships
      let invitationsResult = try await fetchedInvitations
      let suggestionsResult = try await fetchedSuggestions

      membershipsPager.replace(data: membershipsResult.data, totalCount: membershipsResult.totalCount)
      invitationsPager.replace(data: invitationsResult.data, totalCount: invitationsResult.totalCount)
      suggestionsPager.replace(data: suggestionsResult.data, totalCount: suggestionsResult.totalCount)
      creationDefaults = await fetchedDefaults
    } catch {
      self.error = error
    }
  }

  func loadMoreMemberships(user: User?) async {
    guard let user, !isLoadingMore, membershipsPager.hasNextPage else { return }

    membershipsPager.isLoadingMore = true
    defer { membershipsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationMemberships(.init(initialPage: Double(membershipsPager.nextPage), pageSize: Double(pageSize)))
      membershipsPager.append(data: result.data, totalCount: result.totalCount)
    } catch {
      self.error = error
    }
  }

  func loadMoreInvitations(user: User?) async {
    guard let user, !isLoadingMore, invitationsPager.hasNextPage else { return }

    invitationsPager.isLoadingMore = true
    defer { invitationsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationInvitations(.init(initialPage: Double(invitationsPager.nextPage), pageSize: Double(pageSize), status: .pending))
      invitationsPager.append(data: result.data, totalCount: result.totalCount)
    } catch {
      self.error = error
    }
  }

  func loadMoreSuggestions(user: User?) async {
    guard let user, !isLoadingMore, suggestionsPager.hasNextPage else { return }

    suggestionsPager.isLoadingMore = true
    defer { suggestionsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationSuggestions(.init(initialPage: Double(suggestionsPager.nextPage), pageSize: Double(pageSize), status: .case3([.pending, .accepted])))
      suggestionsPager.append(data: result.data, totalCount: result.totalCount)
    } catch {
      self.error = error
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
