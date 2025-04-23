//
//  SecuredByClerkView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct SecuredByClerkView: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    HStack(spacing: 6) {
      Text("Secured by", bundle: .module)
      Image("clerk-logo", bundle: .module)
    }
    .font(theme.fonts.footnote.weight(.medium))
    .foregroundStyle(theme.colors.textSecondary)
  }
}

#Preview {
  SecuredByClerkView()
}

#endif
