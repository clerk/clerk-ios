//
//  PressedBackgroundButtonStyle.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

import SwiftUI

struct PressedBackgroundButtonStyle: ButtonStyle {
  @Environment(\.clerkTheme) private var theme
  
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(configuration.isPressed ? theme.colors.backgroundSecondary : nil)
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
