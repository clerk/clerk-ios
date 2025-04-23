//
//  IdentityPreviewView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/17/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct IdentityPreviewView: View {
  @Environment(\.clerkTheme) private var theme
  
  let label: String
  
  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .font(theme.fonts.subheadline)
        .frame(minHeight: 20)
      Image("edit", bundle: .module)
        .resizable()
        .frame(width: 16, height: 16)
        .scaledToFit()
        .foregroundStyle(theme.colors.textSecondary)
    }
  }
}

#Preview {
  IdentityPreviewView(label: "example@email.com")
}

#endif
