//
//  PressedBackgroundButtonStyle.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

import SwiftUI

struct PressedBackgroundButtonStyle: ButtonStyle {
  @Environment(\.clerkTheme) private var theme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(configuration.isPressed ? theme.colors.muted : nil)
  }
}

extension ButtonStyle where Self == PressedBackgroundButtonStyle {
  static var pressedBackground: PressedBackgroundButtonStyle {
    .init()
  }
}

#Preview {
  Button {
    //
  } label: {
    Text("Continue", bundle: .module)
  }
  .buttonStyle(.pressedBackground)
}

#endif
