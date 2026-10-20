//
//  OrganizationAccountListPager.swift
//

import ClerkKit

struct OrganizationAccountListPager<Item: Codable & Sendable> {
  private(set) var items: [Item] = []
  private(set) var totalCount = 0
  private(set) var offset = 0
  private(set) var hasRoleSetMigration = false
  var isLoadingMore = false

  var hasNextPage: Bool {
    offset < totalCount
  }

  mutating func replace(with pages: [ClerkPaginatedResponse<Item>]) {
    guard let lastPage = pages.last else {
      self = Self()
      return
    }

    items = pages.flatMap(\.data)
    totalCount = lastPage.totalCount
    offset = items.count
    hasRoleSetMigration = pages.first?.hasRoleSetMigration ?? false
  }

  mutating func append(_ page: ClerkPaginatedResponse<Item>) {
    items.append(contentsOf: page.data)
    totalCount = page.totalCount
    offset += page.data.count
  }

  private mutating func removeOneFromPagination() {
    offset = max(0, offset - 1)
    totalCount = max(0, totalCount - 1)
  }
}

extension OrganizationAccountListPager where Item: Identifiable {
  @discardableResult
  mutating func replace(_ item: Item) -> Bool {
    guard let index = items.firstIndex(where: { $0.id == item.id }) else { return false }

    items[index] = item
    return true
  }

  mutating func resolve(_ item: Item) {
    if replace(item) {
      removeOneFromPagination()
    }
  }

  mutating func remove(_ item: Item) {
    if let index = items.firstIndex(where: { $0.id == item.id }) {
      items.remove(at: index)
      removeOneFromPagination()
    }
  }
}
