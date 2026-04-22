//
//  MacOSBackButton.swift
//

#if os(macOS)

import SwiftUI

struct MacOSBackButton: View {
  @Environment(AuthNavigation.self) private var navigation
  @Environment(\.clerkTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack {
      Button {
        navigation.path.removeLast()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(colorScheme == .dark ? Color(white: 0.25) : .white)
          .frame(width: 28, height: 28)
          .background(
            Circle()
              .fill(colorScheme == .dark ? .white : Color(white: 0.25))
          )
      }
      .buttonStyle(.plain)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(colorScheme == .dark ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(theme.colors.background))
    .overlay(alignment: .bottom) {
      Divider()
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
  }
}

extension View {
  @ViewBuilder
  func macOSBackButton(hidden: Bool = false) -> some View {
    if hidden {
      self
    } else {
      VStack(spacing: 0) {
        MacOSBackButton()
        self
      }
    }
  }
}

#endif
