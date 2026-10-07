//
//  OrganizationMembersDataSource+MembershipRequests.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension OrganizationMembersDataSource {
  func loadMembershipRequests(organization: Organization) async {
    guard !Task.isCancelled else { return }

    membershipRequestsRequestID += 1
    let requestID = membershipRequestsRequestID
    isLoadingMembershipRequests = true
    loadMoreMembershipRequestsIsDeferred = loadMoreMembershipRequestsIsDeferred || membershipRequestsPager.isLoadingMore
    membershipRequestsPager.isLoadingMore = false

    do {
      let page = try await organization.getMembershipRequests(page: 1, pageSize: pageSize, status: "pending")
      if requestID == membershipRequestsRequestID, !Task.isCancelled {
        membershipRequestsPager.replace(with: page)
      }
    } catch {
      if requestID == membershipRequestsRequestID, !error.isCancellationError {
        self.error = error
        ClerkLogger.error("Failed to load organization membership requests", error: error)
      }
    }

    guard requestID == membershipRequestsRequestID else { return }

    isLoadingMembershipRequests = false
    guard loadMoreMembershipRequestsIsDeferred else { return }

    loadMoreMembershipRequestsIsDeferred = false
    Task { [weak self] in
      await self?.loadMoreMembershipRequests(organization: organization)
    }
  }

  func loadMoreMembershipRequests(organization: Organization) async {
    guard !membershipRequestsPager.isLoadingMore, membershipRequestsPager.hasNextPage else { return }
    guard !isLoadingMembershipRequests else {
      loadMoreMembershipRequestsIsDeferred = true
      return
    }

    let requestID = membershipRequestsRequestID
    membershipRequestsPager.isLoadingMore = true
    defer {
      if requestID == membershipRequestsRequestID {
        membershipRequestsPager.isLoadingMore = false
      }
    }

    do {
      let page = try await organization.getMembershipRequests(
        offset: membershipRequestsPager.offset,
        pageSize: pageSize,
        status: "pending"
      )
      guard requestID == membershipRequestsRequestID, !Task.isCancelled else { return }

      membershipRequestsPager.append(page)
    } catch {
      guard requestID == membershipRequestsRequestID, !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization membership requests", error: error)
    }
  }
}

#endif
