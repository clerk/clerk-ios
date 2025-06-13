//
//  SecuredByClerkView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if os(iOS)

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

  struct SecuredByClerkFooter: View {
    @Environment(\.clerkTheme) private var theme

    var body: some View {
      SecuredByClerkView()
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(theme.colors.backgroundSecondary)
        .overlay(alignment: .top, content: {
          Rectangle()
            .fill(theme.colors.border)
            .frame(height: 1)
        })
    }
  }

  #Preview {
    SecuredByClerkView()
  }

  #Preview {
    @Environment(\.clerkTheme) var theme

    VStack(spacing: 0) {
      ScrollView {
        theme.colors.backgroundSecondary
          .containerRelativeFrame(.vertical)
      }
      SecuredByClerkFooter()
    }
  }

#endif
