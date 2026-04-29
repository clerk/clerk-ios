//
//  OrganizationPaginatedListSection.swift
//

#if os(iOS)

import SwiftUI

struct OrganizationPaginatedListSection<Item: Identifiable, Content: View>: View {
  let items: [Item]
  let hasNextPage: Bool
  let onLoadMore: () async -> Void
  let content: (Item) -> Content

  init(
    items: [Item],
    hasNextPage: Bool,
    onLoadMore: @escaping () async -> Void,
    @ViewBuilder content: @escaping (Item) -> Content
  ) {
    self.items = items
    self.hasNextPage = hasNextPage
    self.onLoadMore = onLoadMore
    self.content = content
  }

  var body: some View {
    ForEach(items) { item in
      content(item)
        .onAppear {
          guard hasNextPage, item.id == items.last?.id else { return }
          Task { await onLoadMore() }
        }
      Divider()
    }
  }
}

#endif
