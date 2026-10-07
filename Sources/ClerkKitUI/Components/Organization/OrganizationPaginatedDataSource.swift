//
//  OrganizationPaginatedDataSource.swift
//

import ClerkKit
import Foundation

@MainActor
protocol OrganizationPaginatedDataSource: AnyObject {
  var error: Error? { get set }
}

extension OrganizationPaginatedDataSource {
  typealias ListPager<Item: Codable & Sendable> = ReferenceWritableKeyPath<Self, OrganizationAccountListPager<Item>>
  typealias PageFetch<Item: Codable & Sendable> = @MainActor (_ offset: Int) async throws -> ClerkPaginatedResponse<Item>

  func loadFirstPage<Item>(
    _ pager: ListPager<Item>,
    isLoading: ReferenceWritableKeyPath<Self, Bool>,
    listName: String,
    fetch: @escaping PageFetch<Item>
  ) async {
    guard !Task.isCancelled else { return }

    let requestID = self[keyPath: pager].startFirstPageLoad()
    self[keyPath: isLoading] = true

    do {
      let page = try await fetch(0)
      if requestID == self[keyPath: pager].requestID, !Task.isCancelled {
        self[keyPath: pager].replace(with: page)
      }
    } catch {
      if requestID == self[keyPath: pager].requestID, !Task.isCancelled, !error.isCancellationError {
        self.error = error
        ClerkLogger.error("Failed to load organization \(listName)", error: error)
      }
    }

    guard requestID == self[keyPath: pager].requestID else { return }

    self[keyPath: isLoading] = false
    guard self[keyPath: pager].loadMoreIsDeferred else { return }

    self[keyPath: pager].loadMoreIsDeferred = false
    Task { [weak self] in
      guard let self, requestID == self[keyPath: pager].requestID else { return }

      await loadNextPage(pager, isLoading: isLoading, listName: listName, fetch: fetch)
    }
  }

  func loadNextPage<Item>(
    _ pager: ListPager<Item>,
    isLoading: KeyPath<Self, Bool>,
    listName: String,
    fetch: PageFetch<Item>
  ) async {
    guard !self[keyPath: pager].isLoadingMore, self[keyPath: pager].hasNextPage else { return }
    guard !self[keyPath: isLoading] else {
      self[keyPath: pager].loadMoreIsDeferred = true
      return
    }

    let requestID = self[keyPath: pager].requestID
    self[keyPath: pager].isLoadingMore = true
    defer {
      if requestID == self[keyPath: pager].requestID {
        self[keyPath: pager].isLoadingMore = false
      }
    }

    do {
      let page = try await fetch(self[keyPath: pager].offset)
      guard requestID == self[keyPath: pager].requestID, !Task.isCancelled else { return }

      self[keyPath: pager].append(page)
    } catch {
      guard requestID == self[keyPath: pager].requestID, !Task.isCancelled, !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization \(listName)", error: error)
    }
  }
}
