//
//  ErrorText.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct ErrorText: View {
  @Environment(\.clerkTheme) private var theme

  let text: Text
  var alignment: Alignment = .center

  init(error: Error, alignment: Alignment = .center) {
    text = Text(verbatim: error.localizedDescription)
    self.alignment = alignment
  }

  init(text: Text, alignment: Alignment = .center) {
    self.text = text
    self.alignment = alignment
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Image("icon-warning", bundle: .module)
        .resizable()
        .frame(width: 16, height: 16)
        .scaledToFit()
        .offset(y: 3)
      text
        .multilineTextAlignment(.leading)
    }
    .foregroundStyle(theme.colors.danger)
    .frame(maxWidth: .infinity, alignment: alignment)
  }
}

#Preview {
  ErrorText(error: ClerkClientError(message: "Password is incorrect. Try again, or use another method."))
    .padding()
}

#endif
