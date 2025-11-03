//
//  ErrorText.swift
//  Clerk
//
//  Created by Mike Pitre on 5/7/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct ErrorText: View {
  @Environment(\.clerkTheme) private var theme

  let error: Error
  var alignment: Alignment = .center

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Image("icon-warning", bundle: .module)
        .resizable()
        .frame(width: 16, height: 16)
        .scaledToFit()
        .offset(y: 3)
      Text(error.localizedDescription)
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
