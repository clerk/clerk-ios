//
//  HeaderView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/18/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct HeaderView: View {
  @Environment(\.clerkTheme) private var theme

  let style: Style
  let text: LocalizedStringKey

  enum Style {
    case title
    case subtitle
  }

  var font: Font {
    switch style {
    case .title:
      theme.fonts.title2
    case .subtitle:
      theme.fonts.subheadline
    }
  }

  var fontWeight: Font.Weight {
    switch style {
    case .title:
      .bold
    case .subtitle:
      .regular
    }
  }
  
  var minHeight: CGFloat {
    switch style {
    case .title:
      28
    case .subtitle:
      20
    }
  }
  
  var foregroundStyle: Color {
    switch style {
    case .title:
      theme.colors.text
    case .subtitle:
      theme.colors.textSecondary
    }
  }

  var body: some View {
    Text(text, bundle: .module)
      .font(font)
      .fontWeight(fontWeight)
      .multilineTextAlignment(.center)
      .frame(minHeight: minHeight)
      .foregroundStyle(foregroundStyle)
  }
}

#Preview {
  HeaderView(style: .title, text: "Hello, World!")
  HeaderView(style: .subtitle, text: "Hello, World!")
}

#endif
