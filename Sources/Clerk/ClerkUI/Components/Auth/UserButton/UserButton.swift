//
//  UserButton.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if canImport(SwiftUI)

  import Kingfisher
  import SwiftUI

  public struct UserButton: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    
    @State private var userButtonPopoverIsPresented: Bool = false
    
    public init() {}

    public var body: some View {
      ZStack {
        if let user = clerk.user {
          Button {
            userButtonPopoverIsPresented = true
          } label: {
            KFImage(URL(string: user.imageUrl))
              .placeholder { theme.colors.backgroundSecondary }
              .resizable()
              .fade(duration: 0.2)
              .scaledToFill()
              .clipShape(.circle)
          }
        }
      }
      .frame(width: 36, height: 36)
      .popover(isPresented: $userButtonPopoverIsPresented) {
        UserButtonPopover()
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      }
    }
  }

  #Preview {
    UserButton()
      .environment(\.clerk, .mock)
  }

#endif
