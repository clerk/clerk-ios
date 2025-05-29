//
//  WrappingHStack.swift
//  Clerk
//
//  Created by Mike Pitre on 5/29/25.
//

#if os(iOS)

  import SwiftUI

  struct WrappingHStack: Layout {
    var alignment: Alignment
    var spacing: CGFloat
    var lineSpacing: CGFloat

    init(alignment: Alignment = .center, spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
      self.alignment = alignment
      self.spacing = spacing
      self.lineSpacing = lineSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      let rows = calculateRows(proposal: proposal, subviews: subviews)

      let maxWidth = rows.map { $0.width }.max() ?? 0
      let totalHeight = rows.enumerated().reduce(0) { result, row in
        let (index, rowData) = row
        return result + rowData.height + (index > 0 ? lineSpacing : 0)
      }

      return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
      let rows = calculateRows(proposal: proposal, subviews: subviews)
      var currentY = bounds.minY

      for row in rows {
        let rowBounds = CGRect(
          x: bounds.minX,
          y: currentY,
          width: bounds.width,
          height: row.height
        )

        placeRow(row: row, in: rowBounds, alignment: alignment)
        currentY += row.height + lineSpacing
      }
    }

    private func calculateRows(proposal: ProposedViewSize, subviews: Subviews) -> [RowData] {
      let availableWidth = proposal.width ?? .infinity
      var rows: [RowData] = []
      var currentRow: [SubviewData] = []
      var currentRowWidth: CGFloat = 0

      for subview in subviews {
        let subviewSize = subview.sizeThatFits(.unspecified)
        let subviewWidth = subviewSize.width
        let requiredWidth = currentRowWidth + (currentRow.isEmpty ? 0 : spacing) + subviewWidth

        if requiredWidth <= availableWidth || currentRow.isEmpty {
          // Add to current row
          if !currentRow.isEmpty {
            currentRowWidth += spacing
          }
          currentRow.append(SubviewData(subview: subview, size: subviewSize))
          currentRowWidth += subviewWidth
        } else {
          // Start new row
          if !currentRow.isEmpty {
            rows.append(RowData(subviews: currentRow, width: currentRowWidth))
          }
          currentRow = [SubviewData(subview: subview, size: subviewSize)]
          currentRowWidth = subviewWidth
        }
      }

      // Add the last row
      if !currentRow.isEmpty {
        rows.append(RowData(subviews: currentRow, width: currentRowWidth))
      }

      return rows
    }

    private func placeRow(row: RowData, in bounds: CGRect, alignment: Alignment) {
      let rowHeight = row.height

      // Calculate horizontal alignment
      let totalRowWidth = row.width
      let startX: CGFloat
      switch alignment.horizontal {
      case .leading:
        startX = bounds.minX
      case .trailing:
        startX = bounds.maxX - totalRowWidth
      default:  // center
        startX = bounds.minX + (bounds.width - totalRowWidth) / 2
      }

      var currentX = startX

      for subviewData in row.subviews {
        let subview = subviewData.subview
        let size = subviewData.size

        // Calculate vertical alignment
        let yPosition: CGFloat
        switch alignment.vertical {
        case .top:
          yPosition = bounds.minY
        case .bottom:
          yPosition = bounds.minY + rowHeight - size.height
        default:  // center
          yPosition = bounds.minY + (rowHeight - size.height) / 2
        }

        let position = CGPoint(x: currentX, y: yPosition)
        subview.place(at: position, proposal: ProposedViewSize(size))

        currentX += size.width + spacing
      }
    }
  }

  // Helper structures
  private struct SubviewData {
    let subview: LayoutSubview
    let size: CGSize
  }

  private struct RowData {
    let subviews: [SubviewData]
    let width: CGFloat

    var height: CGFloat {
      subviews.map { $0.size.height }.max() ?? 0
    }
  }

#endif
