//
//  SocialButtonStack.swift
//  Clerk
//
//  Created by Mike Pitre on 4/23/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct SocialButtonLayout: Layout {
  enum Alignment {
    case leading, center, trailing
  }

  var alignment: Alignment = .center
  var minItemWidth: CGFloat = 112
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let containerWidth = proposal.width ?? 0
    let itemsPerRow = maxFittingItemCount(containerWidth: containerWidth)
    let rowCount = Int(ceil(Double(subviews.count) / Double(itemsPerRow)))
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let totalHeight = CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * spacing
    return CGSize(width: containerWidth, height: totalHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let containerWidth = bounds.width
    let itemsPerRow = maxFittingItemCount(containerWidth: containerWidth)
    let rowHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
    let rowCount = Int(ceil(Double(subviews.count) / Double(itemsPerRow)))
    let useMaxWidth = subviews.count <= itemsPerRow

    for row in 0..<rowCount {
      let startIndex = row * itemsPerRow
      let endIndex = min(startIndex + itemsPerRow, subviews.count)
      let rowSubviews = subviews[startIndex..<endIndex]
      let itemCount = rowSubviews.count

      let buttonWidth: CGFloat
      if useMaxWidth {
        buttonWidth = (containerWidth - CGFloat(itemCount - 1) * spacing) / CGFloat(itemCount)
      } else {
        buttonWidth = minItemWidth
      }

      let totalRowWidth = CGFloat(itemCount) * buttonWidth + CGFloat(itemCount - 1) * spacing

      let xOffset: CGFloat
      switch alignment {
      case .leading:
        xOffset = 0
      case .center:
        xOffset = (containerWidth - totalRowWidth) / 2
      case .trailing:
        xOffset = containerWidth - totalRowWidth
      }

      for (column, subview) in rowSubviews.enumerated() {
        let x = bounds.minX + xOffset + CGFloat(column) * (buttonWidth + spacing)
        let y = bounds.minY + CGFloat(row) * (rowHeight + spacing)
        subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: buttonWidth, height: rowHeight))
      }
    }
  }

  private func maxFittingItemCount(containerWidth: CGFloat) -> Int {
    guard containerWidth >= minItemWidth else { return 1 }
    let count = (containerWidth + spacing) / (minItemWidth + spacing)
    return max(1, Int(count.rounded(.down)))
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
