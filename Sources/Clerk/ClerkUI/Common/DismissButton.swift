//
//  DismissButton.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct DismissButton: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme
  
  var action: (() -> Void)?
  
  var body: some View {
    Button {
      if let action {
        action()
      } else {
        dismiss()
      }
    } label: {
      Image(systemName: "xmark.circle.fill")
        .resizable()
        .scaledToFit()
        .symbolRenderingMode(.palette)
        .foregroundStyle(theme.colors.textSecondary, .ultraThinMaterial)
        .frame(width: 26, height: 26)
    }
  }
}

#Preview {
  DismissButton()
}

#endif
