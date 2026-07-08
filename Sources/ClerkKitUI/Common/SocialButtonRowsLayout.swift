//
//  SocialButtonRowsLayout.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct SocialButtonRowsLayout: Layout {
  enum Alignment {
    case leading, center, trailing
  }

  var alignment: Alignment = .center
  var stacksTwoItemsInSingleColumn = false
  var minItemWidth: CGFloat = 112
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    let containerWidth = proposal.width ?? 0
    let rows = rows(
      for: subviews,
      maxItemsPerRow: maxRowItemCount(containerWidth: containerWidth, subviewCount: subviews.count)
    )
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let totalHeight = CGFloat(rows.count) * rowHeight + CGFloat(max(0, rows.count - 1)) * spacing
    return CGSize(width: containerWidth, height: totalHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
    let containerWidth = bounds.width
    let rows = rows(
      for: subviews,
      maxItemsPerRow: maxRowItemCount(containerWidth: containerWidth, subviewCount: subviews.count)
    )
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let referenceItemCount = rows.first(where: \.definesItemWidth)?.indices.count ?? rows.first?.indices.count ?? 1

    let buttonWidth = (containerWidth - CGFloat(referenceItemCount - 1) * spacing) / CGFloat(referenceItemCount)

    for (rowIndex, row) in rows.enumerated() {
      let rowButtonWidth = row.usesFullWidth ? containerWidth : buttonWidth
      let itemCount = row.indices.count

      let totalRowWidth = CGFloat(itemCount) * rowButtonWidth + CGFloat(itemCount - 1) * spacing

      let xOffset: CGFloat = switch alignment {
      case .leading:
        0
      case .center:
        (containerWidth - totalRowWidth) / 2
      case .trailing:
        containerWidth - totalRowWidth
      }

      for (column, subviewIndex) in row.indices.enumerated() {
        let subview = subviews[subviewIndex]
        let xPosition = bounds.minX + xOffset + CGFloat(column) * (rowButtonWidth + spacing)
        let yPosition = bounds.minY + CGFloat(rowIndex) * (rowHeight + spacing)
        subview.place(at: CGPoint(x: xPosition, y: yPosition), proposal: ProposedViewSize(width: rowButtonWidth, height: rowHeight))
      }
    }
  }

  private func maxRowItemCount(containerWidth: CGFloat, subviewCount: Int) -> Int {
    guard subviewCount > 0 else { return 1 }
    guard containerWidth >= minItemWidth else { return 1 }
    let count = (containerWidth + spacing) / (minItemWidth + spacing)
    return max(1, min(subviewCount, Int(count.rounded(.down))))
  }

  private func shouldForceSingleColumn(itemCount: Int) -> Bool {
    stacksTwoItemsInSingleColumn && itemCount == 2
  }

  private func rows(for subviews: Subviews, maxItemsPerRow: Int) -> [Row] {
    let indices = Array(subviews.indices)

    if let lastUsedIndex = indices.first(where: { subviews[$0][SocialButtonLastUsedLayoutValueKey.self] }) {
      let remainingIndices = indices.filter { $0 != lastUsedIndex }
      let remainingRows = Self.rowRanges(itemCount: remainingIndices.count, maxItemsPerRow: maxItemsPerRow).map {
        Row(indices: Array(remainingIndices[$0]), usesFullWidth: false, definesItemWidth: true)
      }
      return [Row(indices: [lastUsedIndex], usesFullWidth: true, definesItemWidth: false)] + remainingRows
    }

    return Self.rowRanges(
      itemCount: subviews.count,
      maxItemsPerRow: maxItemsPerRow,
      forceSingleColumn: shouldForceSingleColumn(itemCount: subviews.count)
    ).map {
      Row(indices: Array(indices[$0]), usesFullWidth: false, definesItemWidth: true)
    }
  }

  static func rowRanges(
    itemCount: Int,
    maxItemsPerRow: Int,
    forceSingleColumn: Bool = false
  ) -> [Range<Int>] {
    guard itemCount > 0 else { return [] }
    if forceSingleColumn {
      return (0 ..< itemCount).map { $0 ..< $0 + 1 }
    }

    let maxItemsPerRow = max(1, maxItemsPerRow)
    if itemCount <= maxItemsPerRow {
      return [0 ..< itemCount]
    }

    let rowCount = Int(ceil(Double(itemCount) / Double(maxItemsPerRow)))
    let itemsPerRow = Int(ceil(Double(itemCount) / Double(rowCount)))
    var ranges: [Range<Int>] = []
    var startIndex = 0

    while startIndex < itemCount {
      let endIndex = min(startIndex + itemsPerRow, itemCount)
      ranges.append(startIndex ..< endIndex)
      startIndex = endIndex
    }

    return ranges
  }

  private struct Row {
    let indices: [Int]
    let usesFullWidth: Bool
    let definesItemWidth: Bool
  }
}

#endif
