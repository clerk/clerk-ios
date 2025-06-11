//
//  UserButton.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

  import Kingfisher
  import SwiftUI

  public struct UserButton: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    
    @State private var userProfileIsPresented: Bool = false
    
    public init() {}

    public var body: some View {
      ZStack {
        if let user = clerk.user {
          Button {
            userProfileIsPresented = true
          } label: {
            KFImage(URL(string: user.imageUrl))
              .placeholder { Rectangle().fill(theme.colors.primary.gradient) }
              .resizable()
              .fade(duration: 0.2)
              .scaledToFill()
              .clipShape(.circle)
          }
        }
      }
      .sheet(isPresented: $userProfileIsPresented) {
        UserProfileView(isInSheet: true)
          .presentationDragIndicator(.visible)
      }
      .onChange(of: clerk.user) { _, newValue in
        if newValue == nil {
          userProfileIsPresented = false
        }
      }
    }
  }

  #Preview {
    UserButton()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
