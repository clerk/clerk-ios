//
//  SocialButtonLayout.swift
//  Clerk
//
//  Created by Mike Pitre on 4/23/25.
//

#if os(iOS)

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
    let itemsPerRow = maxRowItemCount(containerWidth: containerWidth, subviewCount: subviews.count)
    let rowCount = Int(ceil(Double(subviews.count) / Double(itemsPerRow)))
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let totalHeight = CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * spacing
    return CGSize(width: containerWidth, height: totalHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
    let containerWidth = bounds.width
    let itemsPerRow = maxRowItemCount(containerWidth: containerWidth, subviewCount: subviews.count)
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let rowCount = Int(ceil(Double(subviews.count) / Double(itemsPerRow)))

    // Calculate button width based on full row (fills container width)
    let buttonWidth = (containerWidth - CGFloat(itemsPerRow - 1) * spacing) / CGFloat(itemsPerRow)

    for row in 0 ..< rowCount {
      let startIndex = row * itemsPerRow
      let endIndex = min(startIndex + itemsPerRow, subviews.count)
      let rowSubviews = subviews[startIndex ..< endIndex]
      let itemCount = rowSubviews.count

      let totalRowWidth = CGFloat(itemCount) * buttonWidth + CGFloat(itemCount - 1) * spacing

      // Center partial rows, full rows naturally fill width
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
}

#Preview {
  ScrollView {
    VStack(spacing: 50) {
      SocialButtonLayout {
        SocialButton(provider: .google)
      }

      SocialButtonLayout {
        SocialButton(provider: .google)
        SocialButton(provider: .apple)
      }

      SocialButtonLayout {
        SocialButton(provider: .google)
        SocialButton(provider: .apple)
        SocialButton(provider: .github)
      }

      SocialButtonLayout {
        SocialButton(provider: .google)
        SocialButton(provider: .apple)
        SocialButton(provider: .github)
        SocialButton(provider: .slack)
      }

      SocialButtonLayout {
        SocialButton(provider: .google)
        SocialButton(provider: .apple)
        SocialButton(provider: .github)
        SocialButton(provider: .slack)
        SocialButton(provider: .facebook)
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
}

#endif
