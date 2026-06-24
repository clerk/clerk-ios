//
//  DevelopmentModeBackgroundView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// The decorative "development mode" footer texture, drawn natively rather than
/// shipped as a baked image. Porting the web's procedural dot field keeps iOS and
/// web in visual lockstep, themes light/dark from `warning` automatically, and
/// scales the oval fade against the live view width (no aspect-ratio cropping).
struct DevelopmentModeBackgroundView: View {
  @Environment(\.clerkTheme) private var theme

  let background: DevelopmentModeBackground
  var spec = DevModeGridSpec()

  var body: some View {
    // Fill the entire background area (including the bottom safe-area extension
    // the caller applies via `.ignoresSafeArea`) so the dot field and bottom line
    // sit flush against the bottom edge of the screen. Both are anchored to the
    // canvas's absolute bottom, so they stay flush regardless of footer height —
    // and since the "Development mode" label isn't touched, the gap between the
    // label and the bottom line grows to the full safe-area extent.
    DevModeGridCanvas(spec: spec, warning: theme.colors.warning, base: baseColor)
      .accessibilityHidden(true)
  }

  /// Solid fill drawn behind the transparent dot field, so the dev-mode footer
  /// reads like the normal footer base it replaces.
  private var baseColor: Color {
    switch background {
    case .white:
      theme.colors.background
    case .gray:
      theme.colors.muted
    }
  }
}

enum DevelopmentModeBackground {
  case white
  case gray
}

// MARK: - Grid spec

/// Parameters and per-cell alpha math for the dot field. The model mirrors the
/// web "development mode" notice (`DevModeNotice.tsx`), tuned for the iOS footer.
struct DevModeGridSpec {
  var squareSize: CGFloat = 2
  var gap: CGFloat = 2
  var minOpacity: Double = 0.1
  var maxOpacity: Double = 0.7
  var contrast: Double = 2
  var fadeWidth: Double = 45 // % of width  → horizontal oval radius
  var fadeHeight: CGFloat = 30 // pt          → vertical oval radius
  var fadeCenterY: Double = 80 // % of height → oval vertical center
  var fadeStrength: Double = 0.98 // edge alpha = 1 - fadeStrength
  var fadeCenter: Double = 0.82 // center alpha
  var lineHeight: CGFloat = 1.5
  var height: CGFloat = 104 // dot-field band height, anchored to the bottom

  /// Final alpha for the square whose top-left is (pointX, pointY), given the live
  /// width and the total canvas height. The `height`-tall dot field is anchored to
  /// the bottom of the canvas, so the oval fade stays pinned to the bottom edge
  /// regardless of how tall the footer (and its safe-area extension) ends up.
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
  /// Stable per-cell pseudo-random in [0, 1). Same (cellX, cellY) → same value, so
  /// the field never flickers across redraws/rotation. Statistically equivalent to
  /// the web field without bit-matching JS's double/uint32 quirks.
  static func cellRandom(_ cellX: Int, _ cellY: Int) -> Double {
    var hash = UInt32(truncatingIfNeeded: cellX &* 374_761_393 &+ cellY &* 668_265_263 &+ 2_246_822_519)
    hash = (hash ^ (hash >> 13)) &* 1_274_126_177
    hash = hash ^ (hash >> 16)
    return Double(hash) / 4_294_967_296.0
  }
}

// MARK: - Canvas

struct DevModeGridCanvas: View {
  let spec: DevModeGridSpec
  let warning: Color
  let base: Color

  var body: some View {
    Canvas { ctx, size in
      // base fill (covers the whole area, including the safe-area extension)
      ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))

      let step = spec.squareSize + spec.gap
      let bandTop = max(0, size.height - spec.height)
      let gridBottom = size.height - spec.lineHeight

      // dots — only within the bottom `height` band, fading toward the bottom edge
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

      // bottom line — flush at the absolute bottom, center-peaked horizontal fade
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
    .drawingGroup()
    .allowsHitTesting(false)
  }
}

#endif
