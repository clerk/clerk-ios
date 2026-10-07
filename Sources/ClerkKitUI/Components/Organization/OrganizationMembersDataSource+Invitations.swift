//
//  OrganizationMembersDataSource+Invitations.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension OrganizationMembersDataSource {
  func loadInvitations(organization: Organization) async {
    guard !Task.isCancelled else { return }

    invitationsRequestID += 1
    let requestID = invitationsRequestID
    isLoadingInvitations = true
    loadMoreInvitationsIsDeferred = loadMoreInvitationsIsDeferred || invitationsPager.isLoadingMore
    invitationsPager.isLoadingMore = false

    do {
      let page = try await organization.getInvitations(page: 1, pageSize: pageSize, status: ["pending"])
      if requestID == invitationsRequestID, !Task.isCancelled {
        invitationsPager.replace(with: page)
      }
    } catch {
      if requestID == invitationsRequestID, !error.isCancellationError {
        self.error = error
        ClerkLogger.error("Failed to load organization invitations", error: error)
      }
    }

    guard requestID == invitationsRequestID else { return }

    isLoadingInvitations = false
    guard loadMoreInvitationsIsDeferred else { return }

    loadMoreInvitationsIsDeferred = false
    Task { [weak self] in
      await self?.loadMoreInvitations(organization: organization)
    }
  }

  func loadMoreInvitations(organization: Organization) async {
    guard !invitationsPager.isLoadingMore, invitationsPager.hasNextPage else { return }
    guard !isLoadingInvitations else {
      loadMoreInvitationsIsDeferred = true
      return
    }

    let requestID = invitationsRequestID
    invitationsPager.isLoadingMore = true
    defer {
      if requestID == invitationsRequestID {
        invitationsPager.isLoadingMore = false
      }
    }

    do {
      let page = try await organization.getInvitations(
        offset: invitationsPager.offset,
        pageSize: pageSize,
        status: ["pending"]
      )
      guard requestID == invitationsRequestID, !Task.isCancelled else { return }

      invitationsPager.append(page)
    } catch {
      guard requestID == invitationsRequestID, !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization invitations", error: error)
    }
  }
}

#endif
