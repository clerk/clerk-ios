//
//  ActionLabel.swift
//

import SwiftUI

struct ActionLabel: View {
  let text: LocalizedStringKey
  var isLoading: Bool = false

  @Environment(\.clerkTheme) private var theme

  init(_ text: LocalizedStringKey, isLoading: Bool = false) {
    self.text = text
    self.isLoading = isLoading
  }

  var body: some View {
    Text(text, bundle: .module)
      .font(.subheadline)
      .foregroundStyle(theme.colors.foreground)
      .overlayProgressView(isActive: isLoading) {
        SpinnerView()
          .frame(width: 14, height: 14)
      }
      .padding(.horizontal, 14)
      .frame(height: 32)
      .background(theme.colors.background)
      .clipShape(.rect(cornerRadius: theme.design.borderRadius))
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
      }
      .shadow(color: theme.colors.buttonBorder, radius: 1, x: 0, y: 1)
  }
}
