//
//  OrganizationPagedList.swift
//

import ClerkKit
import Foundation
import Observation

enum OrganizationListMutation: Equatable {
  case updating
  case removing
  case accepting
  case rejecting
}

@MainActor
@Observable
final class OrganizationPagedList<Item: Codable & Sendable & Identifiable, Query: Sendable> {
  typealias Fetch = @MainActor (_ query: Query, _ offset: Int) async throws -> ClerkPaginatedResponse<Item>

  enum Patch {
    case replace(Item)
    case remove(Item)
    case resolve(Item)
    case reload
  }

  private(set) var pager = OrganizationAccountListPager<Item>()
  private(set) var isLoading: Bool
  private(set) var hasLoaded = false
  private(set) var query: Query?
  private(set) var mutations: [Item.ID: OrganizationListMutation] = [:]

  @ObservationIgnored var onError: (@MainActor (Error) -> Void)?
  @ObservationIgnored private let name: String
  @ObservationIgnored private let fetch: Fetch
  @ObservationIgnored private var generation = 0
  @ObservationIgnored private var isRetired = false
  @ObservationIgnored private var reloadTask: Task<Void, Never>?
  @ObservationIgnored private var loadMoreTask: Task<Void, Never>?
  @ObservationIgnored private var loadMoreAfterReload = false

  init(name: String, isLoading: Bool, fetch: @escaping Fetch) {
    self.name = name
    self.isLoading = isLoading
    self.fetch = fetch
  }

  @discardableResult
  func reload(query: Query) -> Task<Void, Never> {
    load(query: query, throughOffset: 0)
  }

  func refresh() async {
    if let reloadTask {
      await reloadTask.value
    } else if let query {
      await reload(query: query).value
    }
  }

  func revalidate() async {
    guard let query else { return }
    await load(query: query, throughOffset: pager.offset).value
  }

  @discardableResult
  func loadMore() -> Task<Void, Never>? {
    guard !isRetired else { return nil }
    guard reloadTask == nil else {
      loadMoreAfterReload = true
      return nil
    }
    guard pager.hasNextPage, loadMoreTask == nil, hasLoaded, let query else { return loadMoreTask }

    let generation = generation
    let offset = pager.offset
    pager.isLoadingMore = true
    let task = Task { [weak self, fetch] in
      do {
        let page = try await fetch(query, offset)
        self?.finishLoadMore(generation, with: .success(page))
      } catch {
        self?.finishLoadMore(generation, with: .failure(error))
      }
    }
    loadMoreTask = task
    return task
  }

  func mutate(
    _ item: Item,
    as mutation: OrganizationListMutation,
    _ operation: @MainActor () async throws -> Patch
  ) async throws {
    guard !isRetired, mutations[item.id] == nil else { return }

    let generation = generation
    let startedDuringAReload = reloadTask != nil
    mutations[item.id] = mutation
    defer { mutations[item.id] = nil }

    let patch = try await operation()
    guard !isRetired, let query else { return }
    guard generation == self.generation, !startedDuringAReload else {
      await load(query: query, throughOffset: pager.offset).value
      return
    }

    switch patch {
    case .replace(let item):
      pager.replace(item)
    case .remove(let item):
      pager.remove(item)
    case .resolve(let item):
      pager.resolve(item)
    case .reload:
      await reload(query: query).value
    }
  }

  func retire() {
    isRetired = true
    startGeneration()
    loadMoreAfterReload = false
  }

  private func load(query: Query, throughOffset offset: Int) -> Task<Void, Never> {
    guard !isRetired else { return Task {} }

    loadMoreAfterReload = loadMoreAfterReload || loadMoreTask != nil
    startGeneration()
    self.query = query
    isLoading = true
    hasLoaded = false

    let generation = generation
    let task = Task { [weak self, fetch] in
      do {
        let first = try await fetch(query, 0)
        var pages = [first]
        var loaded = first.data.count
        while loaded < offset, let last = pages.last, loaded < last.totalCount, !last.data.isEmpty {
          let page = try await fetch(query, loaded)
          pages.append(page)
          loaded += page.data.count
        }
        self?.finishReload(generation, with: .success(pages))
      } catch {
        self?.finishReload(generation, with: .failure(error))
      }
    }
    reloadTask = task
    return task
  }

  private func startGeneration() {
    generation += 1
    reloadTask?.cancel()
    reloadTask = nil
    loadMoreTask?.cancel()
    loadMoreTask = nil
    pager.isLoadingMore = false
  }

  private func finishReload(_ generation: Int, with result: Result<[ClerkPaginatedResponse<Item>], Error>) {
    guard generation == self.generation else { return }

    reloadTask = nil
    isLoading = false
    switch result {
    case .success(let pages):
      pager.replace(with: pages)
      hasLoaded = true
    case .failure(let error):
      report(error, message: "Failed to load organization \(name)")
    }

    if hasLoaded, loadMoreAfterReload {
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

extension OrganizationPagedList where Query == Void {
  @discardableResult
  func reload() -> Task<Void, Never> {
    reload(query: ())
  }
}
