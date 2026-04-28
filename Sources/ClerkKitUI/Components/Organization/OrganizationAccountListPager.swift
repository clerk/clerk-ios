//
//  OrganizationAccountListPager.swift
//

import ClerkKit

struct OrganizationAccountListPager<Item: Codable & Sendable> {
  var items: [Item] = []
  var totalCount = 0
  var offset = 0
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
