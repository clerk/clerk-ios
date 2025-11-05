//
//  Color+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/17/25.
//

#if os(iOS)

import Foundation
import SwiftUI

extension Color {
  /// Returns whether the color is considered "dark" based on relative luminance.
  var isDark: Bool {
    let rgb = rgbComponents
    let luminance = 0.2126 * rgb.red.luminanceComponent + 0.7152 * rgb.green.luminanceComponent + 0.0722 * rgb.blue.luminanceComponent
    return luminance < 0.5
  }

  /// Mixes the current color with another color by the given amount (0 = self, 1 = other).
  func mix(with color: Color, amount: CGFloat) -> Color {
    let from = rgbComponents
    let to = color.rgbComponents

    let r = from.red + (to.red - from.red) * amount
    let g = from.green + (to.green - from.green) * amount
    let b = from.blue + (to.blue - from.blue) * amount

    return Color(red: Double(r), green: Double(g), blue: Double(b))
  }

  /// Lightens the color by mixing it with white.
  func lighten(by amount: CGFloat) -> Color {
    mix(with: .white, amount: amount)
  }

  /// Darkens the color by mixing it with black.
  func darken(by amount: CGFloat) -> Color {
    mix(with: .black, amount: amount)
  }

  private var rgbComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) {
    #if os(iOS) || os(tvOS) || os(watchOS)
    let uiColor = UIColor(self)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (red, green, blue)
    #elseif os(macOS)
    let nsColor = NSColor(self)
    let rgbColor = nsColor.usingColorSpace(.sRGB) ?? .black
    return (rgbColor.redComponent, rgbColor.greenComponent, rgbColor.blueComponent)
    #endif
  }
}

private extension CGFloat {
  /// Converts an sRGB component to its linearized form for luminance calculation.
  var luminanceComponent: CGFloat {
    self <= 0.03928 ? self / 12.92 : pow((self + 0.055) / 1.055, 2.4)
  }
}

#endif
