//
//  SecondaryButtonStyle.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

import SwiftUI

struct SecondaryButtonStyle: ButtonStyle {
  @Environment(\.clerkTheme) private var theme

  let config: ClerkButtonConfig
  
  func foregroundStyle(configuration: Configuration) -> Color {
    switch config.emphasis {
    case .none:
      configuration.isPressed
      ? theme.colors.text
      : theme.colors.textSecondary
    case .low:
      theme.colors.text
    case .high:
      theme.colors.text
    }
  }
  
  var height: CGFloat {
    switch config.size {
    case .small:
      32
    case .large:
      48
    }
  }

  func backgroundColor(
    configuration: Configuration
  ) -> Color {
    switch config.emphasis {
    case .none:
      configuration.isPressed
      ? theme.colors.backgroundSecondary
      : theme.colors.background
    case .low:
      configuration.isPressed
      ? theme.colors.backgroundSecondary
      : theme.colors.background
    case .high:
      configuration.isPressed
      ? theme.colors.backgroundSecondary
      : theme.colors.background
    }
  }
  
  var borderWidth: CGFloat {
    switch config.emphasis {
    case .none:
      0
    case .low:
      1
    case .high:
      1
    }
  }
  
  var borderColor: Color {
    switch config.emphasis {
    case .none:
      .clear
    case .low:
      theme.colors.buttonBorder
    case .high:
      theme.colors.buttonBorder
    }
  }
  
  var hasShadow: Bool {
    switch config.emphasis {
    case .none:
      false
    case .low:
      true
    case .high:
      true
    }
  }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(theme.fonts.body)
      .foregroundStyle(foregroundStyle(configuration: configuration))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .frame(minHeight: height)
      .frame(maxWidth: .infinity)
      .background {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .fill(backgroundColor(configuration: configuration))
          .overlay {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
              .strokeBorder(borderColor, lineWidth: borderWidth)
          }
      }
      .background {
        if hasShadow {
          RoundedRectangle(cornerRadius: theme.design.borderRadius)
            .fill(backgroundColor(configuration: configuration))
            .shadow(color: theme.colors.buttonBorder, radius: 0.5, x: 0, y: 0.5)
        }
      }
  }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
  static func secondary(
    config: ClerkButtonConfig = .init()
  ) -> SecondaryButtonStyle {
    .init(config: config)
  }
}

#Preview {
  @Previewable @Environment(\.clerkTheme) var theme
  
  VStack(spacing: 20) {
      
    Button {} label: {
      HStack {
        Text("Continue", bundle: .module)
        Image("triangle-right", bundle: .module)
          .opacity(0.6)
      }
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .high,
          size: .large
        )
      )
    )
    
    Button {} label: {
      HStack {
        Text("Continue", bundle: .module)
        Image("triangle-right", bundle: .module)
          .opacity(0.6)
      }
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .high,
          size: .small
        )
      )
    )
    
    Button {} label: {
      HStack {
        Text("Continue", bundle: .module)
        Image("triangle-right", bundle: .module)
          .opacity(0.6)
      }
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .none,
          size: .large
        )
      )
    )
    
    Button {} label: {
      HStack {
        Text("Continue", bundle: .module)
        Image("triangle-right", bundle: .module)
          .opacity(0.6)
      }
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .none,
          size: .small
        )
      )
    )
  }
  .padding()
  .environment(\.clerkTheme, .clerk)

}

