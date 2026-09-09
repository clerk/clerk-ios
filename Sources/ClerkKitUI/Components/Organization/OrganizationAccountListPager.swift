//
//  OrganizationAccountListPager.swift
//

import ClerkKit

@MainActor
struct OrganizationAccountListPager<Item: CoreResource> {
  private(set) var items: [Item] = []
  private(set) var totalCount = 0
  private(set) var offset = 0
  private(set) var nextPage = 1
  var isLoadingMore = false

  var hasNextPage: Bool {
    offset < totalCount
  }

  func loadedPageOffsets(pageSize: Int) -> [Int] {
    let pageSize = max(pageSize, 1)
    let loadedPageCount = max(1, nextPage - 1)
    return (0 ..< loadedPageCount).map { $0 * pageSize }
  }

  mutating func replace(data: [Item], totalCount: Double) {
    items = data
    self.totalCount = Int(exactly: totalCount) ?? data.count
    offset = data.count
    nextPage = 2
  }

  mutating func replace(pages: [(data: [Item], totalCount: Double)]) {
    guard let lastPage = pages.last else {
      self = Self()
      return
    }

    items = pages.flatMap(\.data)
    totalCount = Int(exactly: lastPage.totalCount) ?? items.count
    offset = items.count
    nextPage = pages.count + 1
  }

  mutating func append(data: [Item], totalCount: Double) {
    items.append(contentsOf: data)
    self.totalCount = Int(exactly: totalCount) ?? items.count
    offset += data.count
    nextPage += 1
  }

  mutating func removeOneFromPagination() {
    offset = max(0, offset - 1)
    totalCount = max(0, totalCount - 1)
  }
}

extension OrganizationAccountListPager {
  mutating func replace(_ item: Item) {
    if let index = items.firstIndex(where: { $0.handle == item.handle }) {
      items[index] = item
    }
  }

  mutating func remove(_ item: Item) {
    if let index = items.firstIndex(where: { $0.handle == item.handle }) {
      items.remove(at: index)
      removeOneFromPagination()
    }
  }
}
