//
//  UserPreviewView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

  import Kingfisher
  import SwiftUI

  struct UserPreviewView: View {
    @Environment(\.clerkTheme) private var theme

    let user: User

    var body: some View {
      HStack(spacing: 16) {
        KFImage(URL(string: user.imageUrl))
          .placeholder { theme.colors.primary }
          .resizable()
          .fade(duration: 0.2)
          .scaledToFill()
          .clipShape(.circle)
          .frame(width: 48, height: 48)

        VStack(alignment: .leading, spacing: 4) {
          if let fullName = user.fullName {
            Text(fullName)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.text)
              .frame(minHeight: 22)
          }

          Text(user.identifier)
            .font(
              user.fullName == nil
                ? theme.fonts.body
                : theme.fonts.subheadline
            )
            .foregroundStyle(
              user.fullName == nil
                ? theme.colors.text
                : theme.colors.textSecondary
            )
        }
      }
    }
  }

  #Preview {
    UserPreviewView(user: .mock)
  }

#endif
