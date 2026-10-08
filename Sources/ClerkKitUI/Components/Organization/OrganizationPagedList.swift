//
//  OrganizationPagedList.swift
//

import ClerkKit
import Foundation
import Observation

/// A paginated list that owns the tasks that load it.
///
/// Callers request loads synchronously and the list runs them in its own tasks, so cancelling
/// a view's task never cancels a load. Each reload starts a new generation that cancels the
/// previous one, and only the current generation's pages and errors are applied.
@MainActor
@Observable
final class OrganizationPagedList<Item: Codable & Sendable> {
  typealias Fetch = @MainActor (_ offset: Int) async throws -> ClerkPaginatedResponse<Item>

  private(set) var pager = OrganizationAccountListPager<Item>()
  private(set) var isLoading: Bool
  /// Whether the latest reload finished successfully.
  private(set) var hasLoaded = false

  @ObservationIgnored var onError: (@MainActor (Error) -> Void)?
  @ObservationIgnored private let name: String
  @ObservationIgnored private var fetch: Fetch?
  @ObservationIgnored private var generation = 0
  @ObservationIgnored private var reloadTask: Task<Void, Never>?
  @ObservationIgnored private var loadMoreTask: Task<Void, Never>?
  @ObservationIgnored private var loadMoreAfterReload = false

  init(name: String, isLoading: Bool = true) {
    self.name = name
    self.isLoading = isLoading
  }

  /// Loads the first page with `fetch`, replacing any load in flight.
  ///
  /// A load more that the reload cancels, or that is requested while it runs, runs once it finishes.
  @discardableResult
  func reload(_ fetch: @escaping Fetch) -> Task<Void, Never> {
    loadMoreAfterReload = loadMoreAfterReload || loadMoreTask != nil
    startGeneration()
    self.fetch = fetch
    isLoading = true
    hasLoaded = false

    let generation = generation
    let task = Task { [weak self] in
      do {
        let page = try await fetch(0)
        self?.finishReload(generation, with: .success(page))
      } catch {
        self?.finishReload(generation, with: .failure(error))
      }
    }
    reloadTask = task
    return task
  }

  /// Waits for the reload in flight, or reloads with the last fetch when none is running.
  func refresh() async {
    if let reloadTask {
      await reloadTask.value
    } else if let fetch {
      await reload(fetch).value
    }
  }

  @discardableResult
  func loadMore() -> Task<Void, Never>? {
    guard pager.hasNextPage, loadMoreTask == nil, let fetch else { return loadMoreTask }
    guard reloadTask == nil else {
      loadMoreAfterReload = true
      return nil
    }

    let generation = generation
    let offset = pager.offset
    pager.isLoadingMore = true
    let task = Task { [weak self] in
      do {
        let page = try await fetch(offset)
        self?.finishLoadMore(generation, with: .success(page))
      } catch {
        self?.finishLoadMore(generation, with: .failure(error))
      }
    }
    loadMoreTask = task
    return task
  }

  /// Cancels any load and empties the list.
  func reset(isLoading: Bool) {
    startGeneration()
    fetch = nil
    loadMoreAfterReload = false
    pager = OrganizationAccountListPager()
    self.isLoading = isLoading
    hasLoaded = false
  }

  /// Changes the loaded items in place, for example after accepting or removing one.
  func update(_ change: (inout OrganizationAccountListPager<Item>) -> Void) {
    change(&pager)
  }

  private func startGeneration() {
    generation += 1
    reloadTask?.cancel()
    reloadTask = nil
    loadMoreTask?.cancel()
    loadMoreTask = nil
    pager.isLoadingMore = false
  }

  private func finishReload(_ generation: Int, with result: Result<ClerkPaginatedResponse<Item>, Error>) {
    guard generation == self.generation else { return }

    reloadTask = nil
    isLoading = false
    switch result {
    case .success(let page):
      pager.replace(with: page)
      hasLoaded = true
    case .failure(let error):
      report(error, message: "Failed to load organization \(name)")
    }

    if loadMoreAfterReload {
      loadMoreAfterReload = false
      loadMore()
    }
  }

  private func finishLoadMore(_ generation: Int, with result: Result<ClerkPaginatedResponse<Item>, Error>) {
    guard generation == self.generation else { return }

    loadMoreTask = nil
    pager.isLoadingMore = false
    switch result {
    case .success(let page):
      pager.append(page)
    case .failure(let error):
      report(error, message: "Failed to load more organization \(name)")
    }
  }

  private func report(_ error: Error, message: String) {
    guard !error.isCancellationError else { return }

    onError?(error)
    ClerkLogger.error(message, error: error)
  }
}
