//
//  OrganizationAccountPaginatedList.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationAccountPaginatedList<Item: Identifiable & Codable & Sendable, Row: View>: View {
  @Environment(\.clerkTheme) private var theme

  let pager: OrganizationAccountListPager<Item>
  let isLoading: Bool
  let emptyText: LocalizedStringKey
  let onRefresh: () async -> Void
  let onLoadMore: () async -> Void
  let row: (Item) -> Row

  init(
    pager: OrganizationAccountListPager<Item>,
    isLoading: Bool,
    emptyText: LocalizedStringKey,
    onRefresh: @escaping () async -> Void,
    onLoadMore: @escaping () async -> Void,
    @ViewBuilder row: @escaping (Item) -> Row
  ) {
    self.pager = pager
    self.isLoading = isLoading
    self.emptyText = emptyText
    self.onRefresh = onRefresh
    self.onLoadMore = onLoadMore
    self.row = row
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        Divider()

        if isLoading, pager.items.isEmpty {
          SpinnerView()
            .frame(width: 24, height: 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if pager.items.isEmpty {
          Text(emptyText, bundle: .module)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
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
  }
}

#endif
