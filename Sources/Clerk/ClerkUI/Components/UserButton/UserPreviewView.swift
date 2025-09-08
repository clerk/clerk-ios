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
          .placeholder { Rectangle().fill(theme.colors.primary.gradient) }
          .resizable()
          .fade(duration: 0.2)
          .scaledToFill()
          .clipShape(.circle)
          .frame(width: 48, height: 48)

        VStack(alignment: .leading, spacing: 4) {
          if let fullName = user.fullName {
            Text(fullName)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.foreground)
              .frame(minHeight: 22)
          }

          if let identifier = user.identifier {
            Text(identifier)
              .font(
                user.fullName == nil
                  ? theme.fonts.body
                  : theme.fonts.subheadline
              )
              .foregroundStyle(
                user.fullName == nil
                  ? theme.colors.foreground
                  : theme.colors.mutedForeground
              )
          }
        }
      }
    }
  }

  #Preview {
    UserPreviewView(user: .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
