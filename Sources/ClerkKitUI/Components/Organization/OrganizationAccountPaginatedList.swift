//
//  OrganizationAccountPaginatedList.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationAccountPaginatedList<Item: Identifiable & Codable & Sendable, Row: View, EmptyState: View>: View {
  let pager: OrganizationAccountListPager<Item>
  let isLoading: Bool
  let emptyState: (() -> EmptyState)?
  let onRefresh: () async -> Void
  let onLoadMore: () async -> Void
  let row: (Item) -> Row

  init(
    pager: OrganizationAccountListPager<Item>,
    isLoading: Bool,
    onRefresh: @escaping () async -> Void,
    onLoadMore: @escaping () async -> Void,
    @ViewBuilder row: @escaping (Item) -> Row
  ) where EmptyState == EmptyView {
    self.pager = pager
    self.isLoading = isLoading
    emptyState = nil
    self.onRefresh = onRefresh
    self.onLoadMore = onLoadMore
    self.row = row
  }

  init(
    pager: OrganizationAccountListPager<Item>,
    isLoading: Bool,
    @ViewBuilder emptyState: @escaping () -> EmptyState,
    onRefresh: @escaping () async -> Void,
    onLoadMore: @escaping () async -> Void,
    @ViewBuilder row: @escaping (Item) -> Row
  ) {
    self.pager = pager
    self.isLoading = isLoading
    self.emptyState = emptyState
    self.onRefresh = onRefresh
    self.onLoadMore = onLoadMore
    self.row = row
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        if isLoading, pager.items.isEmpty {
          SpinnerView()
            .frame(width: 24, height: 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if pager.items.isEmpty, let emptyState {
          emptyState()
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, count: 5, span: 4, spacing: 0)
        } else if !pager.items.isEmpty {
          Divider()

          OrganizationPaginatedListSection(
            items: pager.items,
            hasNextPage: pager.hasNextPage,
            onLoadMore: onLoadMore,
            content: row
          )

          if pager.isLoadingMore {
            SpinnerView()
              .frame(width: 24, height: 24)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
          }
        }
      }
    }
    .refreshable {
      await onRefresh()
    }
    #if os(macOS)
    .frame(minHeight: 260)
    #endif
  }
}

#endif
