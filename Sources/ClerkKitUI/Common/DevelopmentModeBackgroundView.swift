//
//  DevelopmentModeBackgroundView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct DevelopmentModeBackgroundView: View {
  @Environment(\.clerkTheme) private var theme

  let spec = DevModeGridSpec()

  var body: some View {
    Canvas { ctx, size in
      let warning = theme.colors.warning
      let step = spec.squareSize + spec.gap
      let bandTop = max(0, size.height - spec.height)
      let gridBottom = size.height - spec.lineHeight

      var posY = bandTop
      while posY < gridBottom {
        var posX: CGFloat = 0
        while posX < size.width {
          let opacity = spec.alpha(pointX: posX, pointY: posY, width: size.width, totalHeight: size.height)
          if opacity > 0.01 {
            ctx.fill(
              Path(CGRect(x: posX, y: posY, width: spec.squareSize, height: spec.squareSize)),
              with: .color(warning.opacity(opacity))
            )
          }
          posX += step
        }
        posY += step
      }

      let lineRect = CGRect(
        x: 0,
        y: size.height - spec.lineHeight,
        width: size.width,
        height: spec.lineHeight
      )
      ctx.fill(
        Path(lineRect),
        with: .linearGradient(
          Gradient(stops: [
            .init(color: warning.opacity(0), location: 0.02),
            .init(color: warning, location: 0.5),
            .init(color: warning.opacity(0), location: 0.98),
          ]),
          startPoint: CGPoint(x: 0, y: 0),
          endPoint: CGPoint(x: size.width, y: 0)
        )
      )
    }
      .accessibilityHidden(true)
      .allowsHitTesting(false)
  }
}

// MARK: - Grid spec

struct DevModeGridSpec {
  let squareSize: CGFloat = 2
  let gap: CGFloat = 2
  let minOpacity: Double = 0.1
  let maxOpacity: Double = 0.7
  let contrast: Double = 2
  let fadeWidth: Double = 45
  let fadeHeight: CGFloat = 30
  let fadeCenterY: Double = 80
  let fadeStrength: Double = 0.98
  let fadeCenter: Double = 0.82
  let lineHeight: CGFloat = 1.5
  let height: CGFloat = 104

  func alpha(pointX: CGFloat, pointY: CGFloat, width: CGFloat, totalHeight: CGFloat) -> Double {
    let bandTop = totalHeight - height
    let centerX = width / 2
    let centerY = bandTop + height * CGFloat(fadeCenterY) / 100
    let radiusX = width * CGFloat(fadeWidth) / 100
    let radiusY = fadeHeight
    let deltaX = (pointX + squareSize / 2 - centerX) / radiusX
    let deltaY = (pointY + squareSize / 2 - centerY) / radiusY
    let distance = min(1, (deltaX * deltaX + deltaY * deltaY).squareRoot())
    let fade = fadeCenter + (1 - fadeStrength - fadeCenter) * Double(distance)
    let base = minOpacity + (maxOpacity - minOpacity)
      * pow(DevModeHash.cellRandom(Int(pointX), Int(pointY)), contrast)
    return base * max(0, fade)
  }
}

// MARK: - Deterministic per-cell PRNG

enum DevModeHash {
  static func cellRandom(_ cellX: Int, _ cellY: Int) -> Double {
    var hash = UInt32(truncatingIfNeeded: cellX &* 374_761_393 &+ cellY &* 668_265_263 &+ 2_246_822_519)
    hash = (hash ^ (hash >> 13)) &* 1_274_126_177
    hash = hash ^ (hash >> 16)
    return Double(hash) / 4_294_967_296.0
  }
}

#endif
