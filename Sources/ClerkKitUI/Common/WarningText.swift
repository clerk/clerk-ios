//
//  WarningText.swift
//

#if os(iOS)

import SwiftUI

struct WarningText: View {
  @Environment(\.clerkTheme) private var theme

  private let text: Text

  init(_ key: LocalizedStringKey, bundle: Bundle? = nil) {
    text = Text(key, bundle: bundle)
  }

  init(verbatim content: String) {
    text = Text(verbatim: content)
  }

  var body: some View {
    text
      .foregroundStyle(theme.colors.warning)
      .font(theme.fonts.subheadline)
      .multilineTextAlignment(.center)
  }
}

#endif
