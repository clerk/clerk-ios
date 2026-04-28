//
//  OrganizationAccountListModel.swift
//

import ClerkKit
import Foundation
import Observation

@MainActor
@Observable
final class OrganizationAccountListModel {
  let pageSize: Int

  var membershipsPager = OrganizationAccountListPager<OrganizationMembership>()
  var invitationsPager = OrganizationAccountListPager<UserOrganizationInvitation>()
  var suggestionsPager = OrganizationAccountListPager<OrganizationSuggestion>()
  var creationDefaults: OrganizationCreationDefaults?
  var isLoading = true
  var error: Error?

  private var acceptedInvitationOrgIds: Set<String> = []

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
    guard let user else { return }

    isLoading = true
    error = nil

    do {
      async let fetchedMemberships = user.getOrganizationMemberships(page: 1, pageSize: pageSize)
      async let fetchedInvitations = user.getOrganizationInvitations(page: 1, pageSize: pageSize, status: "pending")
      async let fetchedSuggestions = user.getOrganizationSuggestions(page: 1, pageSize: pageSize, status: ["pending", "accepted"])
      async let fetchedDefaults = fetchCreationDefaults(user: user, isEnabled: includeCreationDefaults)

      let membershipsResult = try await fetchedMemberships
      let invitationsResult = try await fetchedInvitations
      let suggestionsResult = try await fetchedSuggestions

      membershipsPager.replace(with: membershipsResult)
      invitationsPager.replace(with: invitationsResult)
      suggestionsPager.replace(with: suggestionsResult)
      creationDefaults = await fetchedDefaults
      isLoading = false
    } catch {
      self.error = error
    }
  }

  func loadMoreMemberships(user: User?) async {
    guard let user, !isLoadingMore, membershipsPager.hasNextPage else { return }

    membershipsPager.isLoadingMore = true
    defer { membershipsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationMemberships(offset: membershipsPager.offset, pageSize: pageSize)
      membershipsPager.append(result)
    } catch {
      self.error = error
    }
  }

  func loadMoreInvitations(user: User?) async {
    guard let user, !isLoadingMore, invitationsPager.hasNextPage else { return }

    invitationsPager.isLoadingMore = true
    defer { invitationsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationInvitations(offset: invitationsPager.offset, pageSize: pageSize, status: "pending")
      invitationsPager.append(result)
    } catch {
      self.error = error
    }
  }

  func loadMoreSuggestions(user: User?) async {
    guard let user, !isLoadingMore, suggestionsPager.hasNextPage else { return }

    suggestionsPager.isLoadingMore = true
    defer { suggestionsPager.isLoadingMore = false }

    do {
      let result = try await user.getOrganizationSuggestions(offset: suggestionsPager.offset, pageSize: pageSize, status: ["pending", "accepted"])
      suggestionsPager.append(result)
    } catch {
      self.error = error
    }
  }

  func acceptInvitation(_ invitation: UserOrganizationInvitation) async {
    do {
      try await invitation.accept()
      let wasInserted = acceptedInvitationOrgIds.insert(invitation.publicOrganizationData.id).inserted
      guard wasInserted else { return }
      invitationsPager.removeOneFromPagination()
    } catch {
      self.error = error
    }
  }

  func acceptSuggestion(_ suggestion: OrganizationSuggestion) async {
    do {
      let accepted = try await suggestion.accept()
      if let index = suggestionsPager.items.firstIndex(where: { $0.id == suggestion.id }) {
        suggestionsPager.items[index] = accepted
      }
    } catch {
      self.error = error
    }
  }

  func isInvitationAccepted(_ invitation: UserOrganizationInvitation) -> Bool {
    acceptedInvitationOrgIds.contains(invitation.publicOrganizationData.id)
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
