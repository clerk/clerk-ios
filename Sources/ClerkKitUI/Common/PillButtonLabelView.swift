//
//  PillButtonLabelView.swift
//

#if os(iOS)

import SwiftUI

struct PillButtonLabelView: View {
  @Environment(\.clerkTheme) private var theme

  let text: LocalizedStringKey
  var isLoading = false

  init(_ text: LocalizedStringKey, isLoading: Bool = false) {
    self.text = text
    self.isLoading = isLoading
  }

  var body: some View {
    Text(text, bundle: .module)
      .overlayProgressView(isActive: isLoading) {
        SpinnerView()
          .frame(width: 14, height: 14)
      }
      .font(.subheadline)
      .foregroundStyle(theme.colors.foreground)
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

#Preview {
  VStack(spacing: 16) {
    PillButtonLabelView("Upload logo")

    PillButtonLabelView("Join", isLoading: true)
  }
  .padding()
}

#endif
