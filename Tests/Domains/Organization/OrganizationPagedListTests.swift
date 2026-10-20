@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationPagedListTests {
  private let gate = ResponseGate()
  private let offsets = OffsetRecorder()
  private let source = PageSource()

  @Test
  func reloadReplacesTheList() async {
    let list = source.list()
    source.pages["q"] = { _ in page(["a", "b"], totalCount: 2) }

    await list.reload(query: "q").value

    #expect(list.pager.items.map(\.id) == ["a", "b"])
    #expect(!list.isLoading)
    #expect(list.hasLoaded)
  }

  @Test(arguments: [false, true])
  func newerReloadWinsWhenAnOlderOneFinishesLast(olderFails: Bool) async {
    let (list, errors) = listRecordingErrors()
    source.pages["older"] = { [gate] _ in
      await gate.wait("older")
      if olderFails {
        throw URLError(.badServerResponse)
      }
      return page(["old"], totalCount: 1)
    }
    source.pages["newer"] = { _ in page(["new"], totalCount: 1) }

    let older = list.reload(query: "older")
    await list.reload(query: "newer").value
    gate.open("older")
    await older.value

    #expect(list.pager.items.map(\.id) == ["new"])
    #expect(!list.isLoading)
    #expect(errors.values.isEmpty)
  }

  @Test
  func cancellingTheCallerDoesNotCancelTheLoad() async throws {
    let list = source.list()
    source.pages["q"] = { [gate] _ in
      await gate.wait("load")
      return page(["a"], totalCount: 1)
    }
    list.reload(query: "q")

    let caller = Task { await list.refresh() }
    caller.cancel()
    gate.open("load")
    await caller.value
    try await waitUntil { !list.isLoading }

    #expect(list.pager.items.map(\.id) == ["a"])
  }

  @Test
  func refreshJoinsTheReloadInFlight() async throws {
    let list = source.list()
    source.pages["q"] = { [gate, offsets] offset in
      offsets.values.append(offset)
      await gate.wait("load")
      return page(["a"], totalCount: 1)
    }
    list.reload(query: "q")
    try await waitUntil { offsets.values == [0] }

    let refresh = Task { await list.refresh() }
    await Task.yield()
    gate.open("load")
    await refresh.value

    #expect(offsets.values == [0])
    #expect(list.pager.items.map(\.id) == ["a"])
  }

  @Test
  func refreshReloadsTheLastQueryWhenIdle() async {
    let list = source.list()
    source.pages["q"] = { [offsets] offset in
      offsets.values.append(offset)
      return page(["a\(offsets.values.count)"], totalCount: 1)
    }
    await list.reload(query: "q").value

    await list.refresh()

    #expect(offsets.values == [0, 0])
    #expect(list.pager.items.map(\.id) == ["a2"])
  }

  @Test
  func refreshRetriesAFailedFirstLoad() async {
    let list = source.list()
    let fails = FailOnce()
    source.pages["q"] = { _ in
      if fails.take() {
        throw URLError(.badServerResponse)
      }
      return page(["a"], totalCount: 1)
    }
    await list.reload(query: "q").value

    await list.refresh()

    #expect(list.pager.items.map(\.id) == ["a"])
    #expect(list.hasLoaded)
  }

  @Test
  func loadMoreAppendsTheNextPageOnce() async {
    let list = source.list()
    source.pages["q"] = { [offsets] offset in
      offsets.values.append(offset)
      return offset == 0 ? page(["a", "b"], totalCount: 4) : page(["c", "d"], totalCount: 4)
    }
    await list.reload(query: "q").value

    let loadMore = list.loadMore()
    list.loadMore()
    await loadMore?.value

    #expect(offsets.values == [0, 2])
    #expect(list.pager.items.map(\.id) == ["a", "b", "c", "d"])
    #expect(!list.pager.hasNextPage)
    #expect(!list.pager.isLoadingMore)
  }

  @Test(arguments: [false, true])
  func reloadDropsALoadMoreInFlight(loadMoreFails: Bool) async {
    let (list, errors) = listRecordingErrors()
    source.pages["old"] = { [gate] offset in
      guard offset > 0 else { return page(["a", "b"], totalCount: 4) }
      await gate.wait("loadMore")
      if loadMoreFails {
        throw URLError(.badServerResponse)
      }
      return page(["c", "d"], totalCount: 4)
    }
    source.pages["new"] = { _ in page(["new"], totalCount: 1) }
    await list.reload(query: "old").value
    let loadMore = list.loadMore()

    await list.reload(query: "new").value
    gate.open("loadMore")
    await loadMore?.value

    #expect(list.pager.items.map(\.id) == ["new"])
    #expect(!list.pager.isLoadingMore)
    #expect(errors.values.isEmpty)
  }

  @Test
  func loadMoreRequestedDuringAReloadRunsAfterIt() async throws {
    let list = source.list()
    source.pages["first"] = { _ in page(["a", "b"], totalCount: 4) }
    source.pages["second"] = { [gate, offsets] offset in
      offsets.values.append(offset)
      if offset == 0 {
        await gate.wait("reload")
        return page(["a", "b"], totalCount: 4)
      }
      return page(["c", "d"], totalCount: 4)
    }
    await list.reload(query: "first").value
    let reload = list.reload(query: "second")

    #expect(list.loadMore() == nil)
    gate.open("reload")
    await reload.value
    try await waitUntil { list.pager.items.count == 4 }

    #expect(offsets.values == [0, 2])
    #expect(list.pager.items.map(\.id) == ["a", "b", "c", "d"])
  }

  @Test
  func loadMoreAbandonedByAReloadRunsAfterIt() async throws {
    let list = source.list()
    source.pages["first"] = { [gate] offset in
      guard offset > 0 else { return page(["a", "b"], totalCount: 4) }
      await gate.wait("abandoned")
      return page(["stale"], totalCount: 4)
    }
    source.pages["second"] = { offset in
      offset == 0 ? page(["a", "b"], totalCount: 4) : page(["c", "d"], totalCount: 4)
    }
    await list.reload(query: "first").value
    let abandoned = list.loadMore()

    await list.reload(query: "second").value
    try await waitUntil { list.pager.items.count == 4 }
    gate.open("abandoned")
    await abandoned?.value

    #expect(list.pager.items.map(\.id) == ["a", "b", "c", "d"])
  }

  @Test(arguments: [false, true])
  func failedReloadBlocksLoadMoreUntilAReloadSucceeds(requestedDuringReload: Bool) async {
    let list = source.list()
    source.pages["first"] = { _ in page(["old_1", "old_2"], totalCount: 4) }
    source.pages["failing"] = { [gate, offsets] offset in
      offsets.values.append(offset)
      await gate.wait("reload")
      throw URLError(.badServerResponse)
    }
    await list.reload(query: "first").value
    let reload = list.reload(query: "failing")
    if requestedDuringReload {
      list.loadMore()
    }
    gate.open("reload")
    await reload.value
    for _ in 0 ..< 100 {
      await Task.yield()
    }

    #expect(list.loadMore() == nil)
    #expect(offsets.values == [0])
    #expect(list.pager.items.map(\.id) == ["old_1", "old_2"])
  }

  @Test
  func loadMoreRequestedDuringAFailedReloadRunsAfterASuccessfulRetry() async throws {
    let list = source.list()
    let fails = FailOnce()
    source.pages["first"] = { _ in page(["a", "b"], totalCount: 4) }
    source.pages["retried"] = { [gate, offsets] offset in
      offsets.values.append(offset)
      if offset == 0 {
        await gate.wait("reload")
        if fails.take() {
          throw URLError(.badServerResponse)
        }
        return page(["a", "b"], totalCount: 4)
      }
      return page(["c", "d"], totalCount: 4)
    }
    await list.reload(query: "first").value
    let reload = list.reload(query: "retried")
    list.loadMore()
    gate.open("reload")
    await reload.value

    await list.refresh()
    try await waitUntil { list.pager.items.count == 4 }

    #expect(offsets.values == [0, 0, 2])
    #expect(list.pager.items.map(\.id) == ["a", "b", "c", "d"])
  }

  @Test
  func loadMoreRequestedDuringAReloadUsesTheReloadedPage() async throws {
    let list = source.list()
    source.pages["first"] = { _ in page(["a", "b"], totalCount: 2) }
    source.pages["second"] = { [gate, offsets] offset in
      offsets.values.append(offset)
      if offset == 0 {
        await gate.wait("reload")
        return page(["a", "b"], totalCount: 4)
      }
      return page(["c", "d"], totalCount: 4)
    }
    await list.reload(query: "first").value
    let reload = list.reload(query: "second")

    list.loadMore()
    gate.open("reload")
    await reload.value
    try await waitUntil { list.pager.items.count == 4 }

    #expect(offsets.values == [0, 2])
  }

  @Test
  func failedReloadReportsItsErrorOnce() async {
    let (list, errors) = listRecordingErrors()
    source.pages["q"] = { _ in throw URLError(.badServerResponse) }

    await list.reload(query: "q").value

    #expect(errors.values.count == 1)
    #expect(!list.isLoading)
    #expect(!list.hasLoaded)
  }

  @Test
  func retiringDropsALoadFromBeforeIt() async {
    let list = source.list()
    source.pages["q"] = { [gate] _ in
      await gate.wait("load")
      return page(["old"], totalCount: 1)
    }
    let reload = list.reload(query: "q")

    list.retire()
    gate.open("load")
    await reload.value

    #expect(list.pager.items.isEmpty)
  }

  @Test
  func retiredListSendsNoRequestsAndTakesNoPatches() async throws {
    let list = source.list()
    source.pages["q"] = { [offsets] offset in
      offsets.values.append(offset)
      return page(["a", "b"], totalCount: 4)
    }
    await list.reload(query: "q").value
    list.retire()

    await list.reload(query: "q").value
    await list.refresh()
    await list.revalidate()
    #expect(list.loadMore() == nil)
    try await list.mutate(Row(id: "a"), as: .removing) { .remove(Row(id: "a")) }

    #expect(offsets.values == [0])
    #expect(list.pager.items.map(\.id) == ["a", "b"])
    #expect(list.pager.totalCount == 4)
  }

  @Test
  func patchFromBeforeARetireIsDropped() async throws {
    let list = source.list()
    source.pages["q"] = { _ in page(["a", "b"], totalCount: 2) }
    await list.reload(query: "q").value

    let mutation = Task {
      try await list.mutate(Row(id: "a"), as: .removing) { [gate] in
        await gate.wait("mutation")
        return .remove(Row(id: "a"))
      }
    }
    try await waitUntil { list.mutations[Row(id: "a").id] == .removing }
    list.retire()
    gate.open("mutation")
    try await mutation.value

    #expect(list.pager.items.map(\.id) == ["a", "b"])
  }

  @Test
  func mutationMarksItsRowWhileItRuns() async throws {
    let list = source.list()
    source.pages["q"] = { _ in page(["a", "b"], totalCount: 2) }
    await list.reload(query: "q").value

    let mutation = Task {
      try await list.mutate(Row(id: "a"), as: .accepting) { [gate] in
        await gate.wait("mutation")
        return .replace(Row(id: "a"))
      }
    }
    try await waitUntil { list.mutations["a"] == .accepting }
    try await list.mutate(Row(id: "a"), as: .rejecting) { .remove(Row(id: "a")) }
    gate.open("mutation")
    try await mutation.value

    #expect(list.mutations.isEmpty)
    #expect(list.pager.items.map(\.id) == ["a", "b"])
  }

  @Test
  func patchLandingAfterAReloadStartedReloadsInsteadOfPatching() async throws {
    let list = source.list()
    let serverRows = RowsOnServer(["a", "b"])
    source.pages["q"] = { [gate, serverRows] _ in
      let rows = serverRows.ids
      if rows == ["a", "b"], serverRows.reloads > 0 {
        await gate.wait("staleReload")
      }
      serverRows.reloads += 1
      return page(rows, totalCount: rows.count)
    }
    await list.reload(query: "q").value

    let mutation = Task {
      try await list.mutate(Row(id: "a"), as: .removing) { [gate, serverRows] in
        await gate.wait("removal")
        serverRows.ids = ["b"]
        return .remove(Row(id: "a"))
      }
    }
    try await waitUntil { list.mutations["a"] == .removing }
    let staleReload = list.reload(query: "q")
    gate.open("removal")
    try await mutation.value
    gate.open("staleReload")
    await staleReload.value

    #expect(list.pager.items.map(\.id) == ["b"])
    #expect(list.pager.totalCount == 1)
  }

  @Test
  func patchLandingWhileAnOlderReloadRunsReloadsInsteadOfPatching() async throws {
    let list = source.list()
    let serverRows = RowsOnServer(["a", "b"])
    source.pages["q"] = { [gate, serverRows] _ in
      let rows = serverRows.ids
      if serverRows.reloads == 1 {
        serverRows.reloads += 1
        await gate.wait("staleReload")
      } else {
        serverRows.reloads += 1
      }
      return page(rows, totalCount: rows.count)
    }
    await list.reload(query: "q").value
    let staleReload = list.reload(query: "q")
    try await waitUntil { serverRows.reloads == 2 }

    try await list.mutate(Row(id: "a"), as: .removing) { [serverRows] in
      serverRows.ids = ["b"]
      return .remove(Row(id: "a"))
    }
    gate.open("staleReload")
    await staleReload.value

    #expect(list.pager.items.map(\.id) == ["b"])
    #expect(list.pager.totalCount == 1)
  }

  @Test
  func patchLandingAfterARevalidateKeepsEveryLoadedPage() async throws {
    let list = source.list()
    let serverRows = RowsOnServer(["a", "b", "c", "d"])
    source.pages["q"] = { [serverRows] offset in
      let rows = Array(serverRows.ids.dropFirst(offset).prefix(2))
      return page(rows, totalCount: serverRows.ids.count)
    }
    await list.reload(query: "q").value
    await list.loadMore()?.value

    let mutation = Task {
      try await list.mutate(Row(id: "c"), as: .removing) { [gate, serverRows] in
        await gate.wait("removal")
        serverRows.ids = ["a", "b", "d"]
        return .remove(Row(id: "c"))
      }
    }
    try await waitUntil { list.mutations["c"] == .removing }
    await list.revalidate()
    gate.open("removal")
    try await mutation.value

    #expect(list.pager.items.map(\.id) == ["a", "b", "d"])
  }

  @Test
  func resolvingAMissingItemKeepsPagination() async throws {
    let list = source.list()
    source.pages["q"] = { _ in page(["a", "b"], totalCount: 4) }
    await list.reload(query: "q").value

    try await list.mutate(Row(id: "gone"), as: .accepting) { .resolve(Row(id: "gone")) }

    #expect(list.pager.offset == 2)
    #expect(list.pager.totalCount == 4)
  }

  @Test
  func revalidateReloadsEveryLoadedPageAndReplacesTheRowsOnce() async {
    let list = source.list()
    let version = RowsOnServer([])
    source.pages["q"] = { [offsets, version] offset in
      offsets.values.append(offset)
      let prefix = version.reloads == 0 ? "old" : "new"
      return offset == 0 ? page(["\(prefix)_1", "\(prefix)_2"], totalCount: 4) : page(["\(prefix)_3", "\(prefix)_4"], totalCount: 4)
    }
    await list.reload(query: "q").value
    await list.loadMore()?.value
    version.reloads = 1

    await list.revalidate()

    #expect(offsets.values == [0, 2, 0, 2])
    #expect(list.pager.items.map(\.id) == ["new_1", "new_2", "new_3", "new_4"])
    #expect(!list.isLoading)
  }

  @Test
  func revalidateDropsALoadMoreInFlight() async throws {
    let list = source.list()
    let version = RowsOnServer([])
    source.pages["q"] = { [gate, version] offset in
      if offset == 0 {
        return page(["a", "b"], totalCount: 4)
      }
      if version.reloads == 0 {
        await gate.wait("loadMore")
        return page(["stale_c", "stale_d"], totalCount: 4)
      }
      return page(["c", "d"], totalCount: 4)
    }
    await list.reload(query: "q").value
    let loadMore = list.loadMore()
    version.reloads = 1

    await list.revalidate()
    try await waitUntil { list.pager.items.count == 4 }
    gate.open("loadMore")
    await loadMore?.value

    #expect(list.pager.items.map(\.id) == ["a", "b", "c", "d"])
  }

  private func listRecordingErrors() -> (OrganizationPagedList<Row, String>, ErrorRecorder) {
    let list = source.list()
    let errors = ErrorRecorder()
    list.onError = { errors.values.append($0) }
    return (list, errors)
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 1000 where !condition() {
      await Task.yield()
    }
    try #require(condition())
  }
}

private struct Row: Codable, Identifiable {
  let id: String
}

private func page(_ ids: [String], totalCount: Int) -> ClerkPaginatedResponse<Row> {
  ClerkPaginatedResponse(data: ids.map(Row.init), totalCount: totalCount)
}

@MainActor
private final class PageSource {
  var pages: [String: @MainActor (Int) async throws -> ClerkPaginatedResponse<Row>] = [:]

  func list() -> OrganizationPagedList<Row, String> {
    OrganizationPagedList(name: "rows", isLoading: true) { [self] query, offset in
      guard let respond = pages[query] else { throw URLError(.unsupportedURL) }
      return try await respond(offset)
    }
  }
}

@MainActor
private final class RowsOnServer {
  var ids: [String]
  var reloads = 0

  init(_ ids: [String]) {
    self.ids = ids
  }
}

@MainActor
private final class OffsetRecorder {
  var values: [Int] = []
}

@MainActor
private final class FailOnce {
  private var shouldFail = true

  func take() -> Bool {
    defer { shouldFail = false }
    return shouldFail
  }
}

@MainActor
private final class ErrorRecorder {
  var values: [Error] = []
}
