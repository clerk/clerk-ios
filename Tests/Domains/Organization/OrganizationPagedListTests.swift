@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationPagedListTests {
  private let gate = ResponseGate()
  private let offsets = OffsetRecorder()

  @Test
  func reloadReplacesTheList() async {
    let list = OrganizationPagedList<Row>(name: "rows")

    await list.reload { _ in page(["a", "b"], totalCount: 2) }.value

    #expect(list.pager.items.map(\.id) == ["a", "b"])
    #expect(!list.isLoading)
    #expect(list.hasLoaded)
  }

  @Test(arguments: [false, true])
  func newerReloadWinsWhenAnOlderOneFinishesLast(olderFails: Bool) async {
    let (list, errors) = listRecordingErrors()

    let older = list.reload { [gate] _ in
      await gate.wait("older")
      if olderFails {
        throw URLError(.badServerResponse)
      }
      return page(["old"], totalCount: 1)
    }
    await list.reload { _ in page(["new"], totalCount: 1) }.value
    gate.open("older")
    await older.value

    #expect(list.pager.items.map(\.id) == ["new"])
    #expect(!list.isLoading)
    #expect(errors.values.isEmpty)
  }

  @Test
  func cancellingTheCallerDoesNotCancelTheLoad() async throws {
    let list = OrganizationPagedList<Row>(name: "rows")
    list.reload { [gate] _ in
      await gate.wait("load")
      return page(["a"], totalCount: 1)
    }

    let caller = Task { await list.refresh() }
    caller.cancel()
    gate.open("load")
    await caller.value
    try await waitUntil { !list.isLoading }

    #expect(list.pager.items.map(\.id) == ["a"])
  }

  @Test
  func refreshJoinsTheReloadInFlight() async throws {
    let list = OrganizationPagedList<Row>(name: "rows")
    list.reload { [gate, offsets] offset in
      offsets.values.append(offset)
      await gate.wait("load")
      return page(["a"], totalCount: 1)
    }
    try await waitUntil { offsets.values == [0] }

    let refresh = Task { await list.refresh() }
    await Task.yield()
    gate.open("load")
    await refresh.value

    #expect(offsets.values == [0])
    #expect(list.pager.items.map(\.id) == ["a"])
  }

  @Test
  func refreshReloadsWithTheLastFetchWhenIdle() async {
    let list = OrganizationPagedList<Row>(name: "rows")
    await list.reload { [offsets] offset in
      offsets.values.append(offset)
      return page(["a\(offsets.values.count)"], totalCount: 1)
    }.value

    await list.refresh()

    #expect(offsets.values == [0, 0])
    #expect(list.pager.items.map(\.id) == ["a2"])
  }

  @Test
  func loadMoreAppendsTheNextPageOnce() async {
    let list = OrganizationPagedList<Row>(name: "rows")
    await list.reload { [offsets] offset in
      offsets.values.append(offset)
      return offset == 0 ? page(["a", "b"], totalCount: 4) : page(["c", "d"], totalCount: 4)
    }.value

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
    await list.reload { [gate] offset in
      guard offset > 0 else { return page(["a", "b"], totalCount: 4) }
      await gate.wait("loadMore")
      if loadMoreFails {
        throw URLError(.badServerResponse)
      }
      return page(["c", "d"], totalCount: 4)
    }.value
    let loadMore = list.loadMore()

    await list.reload { _ in page(["new"], totalCount: 1) }.value
    gate.open("loadMore")
    await loadMore?.value

    #expect(list.pager.items.map(\.id) == ["new"])
    #expect(!list.pager.isLoadingMore)
    #expect(errors.values.isEmpty)
  }

  @Test
  func loadMoreRequestedDuringAReloadRunsAfterIt() async throws {
    let list = OrganizationPagedList<Row>(name: "rows")
    await list.reload { _ in page(["a", "b"], totalCount: 4) }.value
    let reload = list.reload { [gate, offsets] offset in
      offsets.values.append(offset)
      if offset == 0 {
        await gate.wait("reload")
        return page(["a", "b"], totalCount: 4)
      }
      return page(["c", "d"], totalCount: 4)
    }

    #expect(list.loadMore() == nil)
    gate.open("reload")
    await reload.value
    try await waitUntil { list.pager.items.count == 4 }

    #expect(offsets.values == [0, 2])
    #expect(list.pager.items.map(\.id) == ["a", "b", "c", "d"])
  }

  @Test
  func loadMoreAbandonedByAReloadRunsAfterIt() async throws {
    let list = OrganizationPagedList<Row>(name: "rows")
    await list.reload { [gate] offset in
      guard offset > 0 else { return page(["a", "b"], totalCount: 4) }
      await gate.wait("abandoned")
      return page(["stale"], totalCount: 4)
    }.value
    let abandoned = list.loadMore()

    await list.reload { offset in
      offset == 0 ? page(["a", "b"], totalCount: 4) : page(["c", "d"], totalCount: 4)
    }.value
    try await waitUntil { list.pager.items.count == 4 }
    gate.open("abandoned")
    await abandoned?.value

    #expect(list.pager.items.map(\.id) == ["a", "b", "c", "d"])
  }

  @Test(arguments: [false, true])
  func failedReloadBlocksLoadMoreUntilAReloadSucceeds(requestedDuringReload: Bool) async {
    let list = OrganizationPagedList<Row>(name: "rows")
    await list.reload { _ in page(["old_1", "old_2"], totalCount: 4) }.value
    let reload = list.reload { [gate, offsets] offset in
      offsets.values.append(offset)
      await gate.wait("reload")
      throw URLError(.badServerResponse)
    }
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
  func resetDropsALoadFromBeforeIt() async {
    let list = OrganizationPagedList<Row>(name: "rows")
    let reload = list.reload { [gate] _ in
      await gate.wait("load")
      return page(["old"], totalCount: 1)
    }

    list.reset(isLoading: true)
    gate.open("load")
    await reload.value

    #expect(list.pager.items.isEmpty)
    #expect(list.isLoading)
  }

  @Test
  func failedReloadReportsItsErrorOnce() async {
    let (list, errors) = listRecordingErrors()

    await list.reload { _ in throw URLError(.badServerResponse) }.value

    #expect(errors.values.count == 1)
    #expect(!list.isLoading)
    #expect(!list.hasLoaded)
  }

  private func listRecordingErrors() -> (OrganizationPagedList<Row>, ErrorRecorder) {
    let list = OrganizationPagedList<Row>(name: "rows")
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
private final class OffsetRecorder {
  var values: [Int] = []
}

@MainActor
private final class ErrorRecorder {
  var values: [Error] = []
}
