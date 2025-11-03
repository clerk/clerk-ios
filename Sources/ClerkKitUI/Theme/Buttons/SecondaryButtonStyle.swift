//
//  SecondaryButtonStyle.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if os(iOS)

import SwiftUI

struct SecondaryButtonStyle: ButtonStyle {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.isEnabled) private var isEnabled

  let config: ClerkButtonConfig

  var font: Font {
    switch config.size {
    case .small:
      theme.fonts.subheadline
    case .large:
      theme.fonts.body
    }
  }

  func foregroundStyle(configuration: Configuration) -> Color {
    switch config.emphasis {
    case .none:
      configuration.isPressed
        ? theme.colors.foreground
        : theme.colors.mutedForeground
    case .low:
      theme.colors.foreground
    case .high:
      theme.colors.foreground
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
        ? theme.colors.muted
        : theme.colors.background
    case .low:
      configuration.isPressed
        ? theme.colors.muted
        : theme.colors.background
    case .high:
      configuration.isPressed
        ? theme.colors.muted
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
      .font(font)
      .foregroundStyle(foregroundStyle(configuration: configuration))
      .padding(8)
      .frame(minHeight: height)
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
            .shadow(color: theme.colors.inputBorderFocused, radius: 0.5, x: 0, y: 1)
        }
      }
      .opacity(isEnabled ? 1 : 0.5)
      .animation(.default, value: isEnabled)
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

  struct Content: View {
    var body: some View {
      HStack(spacing: 4) {
        Text("Continue", bundle: .module)
        Image("icon-triangle-right", bundle: .module)
          .opacity(0.6)
      }
    }
  }

  return VStack(spacing: 20) {

    Button {
    } label: {
      Content()
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .high,
          size: .large
        )
      )
    )

    Button {
    } label: {
      Content()
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .high,
          size: .small
        )
      )
    )

    Button {
    } label: {
      Content()
    }
    .buttonStyle(
      .secondary(
        config: .init(
          emphasis: .none,
          size: .large
        )
      )
    )

    Button {
    } label: {
      Content()
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

#endif
