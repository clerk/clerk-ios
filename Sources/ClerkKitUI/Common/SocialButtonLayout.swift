//
//  SocialButtonLayout.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SocialButtonLayout: Layout {
  enum Alignment {
    case leading, center, trailing
  }

  var alignment: Alignment = .center
  var minItemWidth: CGFloat = 112
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    let containerWidth = proposal.width ?? 0
    let rowRanges = Self.rowRanges(
      itemCount: subviews.count,
      maxItemsPerRow: maxRowItemCount(containerWidth: containerWidth, subviewCount: subviews.count)
    )
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let totalHeight = CGFloat(rowRanges.count) * rowHeight + CGFloat(max(0, rowRanges.count - 1)) * spacing
    return CGSize(width: containerWidth, height: totalHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
    let containerWidth = bounds.width
    let rowRanges = Self.rowRanges(
      itemCount: subviews.count,
      maxItemsPerRow: maxRowItemCount(containerWidth: containerWidth, subviewCount: subviews.count)
    )
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let referenceItemCount = rowRanges.first?.count ?? 1

    let buttonWidth = (containerWidth - CGFloat(referenceItemCount - 1) * spacing) / CGFloat(referenceItemCount)

    for (row, rowRange) in rowRanges.enumerated() {
      let rowSubviews = subviews[rowRange]
      let itemCount = rowSubviews.count

      let totalRowWidth = CGFloat(itemCount) * buttonWidth + CGFloat(itemCount - 1) * spacing

      let xOffset: CGFloat = switch alignment {
      case .leading:
        0
      case .center:
        (containerWidth - totalRowWidth) / 2
      case .trailing:
        containerWidth - totalRowWidth
      }

      for (column, subview) in rowSubviews.enumerated() {
        let xPosition = bounds.minX + xOffset + CGFloat(column) * (buttonWidth + spacing)
        let yPosition = bounds.minY + CGFloat(row) * (rowHeight + spacing)
        subview.place(at: CGPoint(x: xPosition, y: yPosition), proposal: ProposedViewSize(width: buttonWidth, height: rowHeight))
      }
    }
  }

  private func maxRowItemCount(containerWidth: CGFloat, subviewCount: Int) -> Int {
    guard subviewCount > 0 else { return 1 }
    guard containerWidth >= minItemWidth else { return 1 }
    let count = (containerWidth + spacing) / (minItemWidth + spacing)
    return max(1, min(subviewCount, Int(count.rounded(.down))))
  }

  static func rowRanges(itemCount: Int, maxItemsPerRow: Int) -> [Range<Int>] {
    guard itemCount > 0 else { return [] }

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
}

#Preview {
  ScrollView {
    VStack(spacing: 50) {
      SocialButtonLayout {
        SocialButton(provider: .google)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
        SocialButton(provider: .github, showsTitle: false)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
        SocialButton(provider: .github, showsTitle: false)
        SocialButton(provider: .slack, showsTitle: false)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
        SocialButton(provider: .github, showsTitle: false)
        SocialButton(provider: .slack, showsTitle: false)
        SocialButton(provider: .facebook, showsTitle: false)
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
  .environment(Clerk.preview())
}

#endif
