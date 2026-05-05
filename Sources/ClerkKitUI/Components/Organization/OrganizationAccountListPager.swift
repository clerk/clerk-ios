//
//  OrganizationAccountListPager.swift
//

import ClerkKit

struct OrganizationAccountListPager<Item: Codable & Sendable> {
  private(set) var items: [Item] = []
  private(set) var totalCount = 0
  private(set) var offset = 0
  var isLoadingMore = false

  var hasNextPage: Bool {
    offset < totalCount
  }

  mutating func replace(with page: ClerkPaginatedResponse<Item>) {
    items = page.data
    totalCount = page.totalCount
    offset = page.data.count
  }

  mutating func append(_ page: ClerkPaginatedResponse<Item>) {
    items.append(contentsOf: page.data)
    totalCount = page.totalCount
    offset += page.data.count
  }

  mutating func removeOneFromPagination() {
    offset = max(0, offset - 1)
    totalCount = max(0, totalCount - 1)
  }
}

extension OrganizationAccountListPager where Item: Identifiable {
  mutating func replace(_ item: Item) {
    if let index = items.firstIndex(where: { $0.id == item.id }) {
      items[index] = item
    }
  }

  mutating func remove(_ item: Item) {
    if let index = items.firstIndex(where: { $0.id == item.id }) {
      items.remove(at: index)
      removeOneFromPagination()
    }
  }
}
