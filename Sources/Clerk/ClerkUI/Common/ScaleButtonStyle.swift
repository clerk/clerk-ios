//
//  ScaleButtonStyle.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

import SwiftUI

struct ScaleButtonStyle: ButtonStyle {

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.default, value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == ScaleButtonStyle {
  static var scale: ScaleButtonStyle { .init() }
}
