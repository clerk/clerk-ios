//
//  PrimaryButtonStyle.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
  @Environment(\.clerkTheme) private var theme

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(theme.fonts.buttonLarge)
      .foregroundStyle(theme.colors.textOnPrimaryBackground)
      .frame(minHeight: 48)
      .frame(maxWidth: .infinity)
      .background {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .fill(
            theme.colors.primary
              .shadow(.drop(color: theme.colors.inputBorderHover, radius: 1, y: 1))
              .shadow(.inner(color: .white, radius: 1))
          )
          .overlay {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
              .strokeBorder(theme.colors.primary, lineWidth: 1)
              .strokeBorder(.black.opacity(0.2), lineWidth: 1)
          }
      }
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.default, value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
  static var primary: PrimaryButtonStyle { .init() }
}

#Preview {
  VStack(spacing: 20) {
    Button(
      action: {
        //
      },
      label: {
        HStack {
          Text("Continue", bundle: .module)
          Image(systemName: "arrowtriangle.right.fill")
            .resizable()
            .scaledToFill()
            .frame(width: 5, height: 6)
        }
      }
    )
    .buttonStyle(.primary)
    
    Button(
      action: {
        //
      },
      label: {
        HStack {
          Text("Continue", bundle: .module)
          Image(systemName: "arrowtriangle.right.fill")
            .resizable()
            .scaledToFill()
            .frame(width: 5, height: 6)
        }
      }
    )
    .buttonStyle(.primary)
    .environment(\.clerkTheme, .clerk)
    
    Button(
      action: {
        //
      },
      label: {
        HStack {
          Text("Continue", bundle: .module)
          Image(systemName: "arrowtriangle.right.fill")
            .resizable()
            .scaledToFill()
            .frame(width: 5, height: 6)
        }
      }
    )
    .buttonStyle(.primary)
    .environment(\.locale, .init(identifier: "es"))
  }
  .padding()
}
