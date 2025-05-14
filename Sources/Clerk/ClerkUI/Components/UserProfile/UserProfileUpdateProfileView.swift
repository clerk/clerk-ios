//
//  UserProfileUpdateProfileView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/14/25.
//

#if os(iOS)

  import Kingfisher
  import SwiftUI

  struct UserProfileUpdateProfileView: View {
    @Environment(\.clerkTheme) private var theme

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""

    let user: User

    var body: some View {
      VStack(spacing: 32) {
        KFImage(URL(string: user.imageUrl))
          .resizable()
          .fade(duration: 0.25)
          .placeholder { theme.colors.primary }
          .scaledToFill()
          .frame(width: 96, height: 96)
          .clipShape(.circle)
          .overlay(alignment: .bottomTrailing) {
            menu
          }

        ClerkTextField("Username", text: $username)
        ClerkTextField("First name", text: $firstName)
        ClerkTextField("Last name", text: $lastName)

        AsyncButton {
          await save()
        } label: { isRunning in
          Text("Save")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
        
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.top, 60)
      .task {
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        username = user.username ?? ""
      }
    }
    
    @ViewBuilder
    private var menu: some View {
      Menu {
        menuContent
      } label: {
        Image("icon-edit", bundle: .module)
          .resizable()
          .scaledToFit()
          .frame(width: 16, height: 16)
          .padding(8)
          .foregroundStyle(theme.colors.textSecondary)
          .background(theme.colors.background)
          .clipShape(.rect(cornerRadius: theme.design.borderRadius))
          .overlay {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
              .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
          }
          .shadow(color: theme.colors.buttonBorder, radius: 1, x: 0, y: 1)
      }
    }
    
    @ViewBuilder
    private var menuContent: some View {
      Button("Choose from photo library") {
        //
      }
      
      Button("Remove photo", role: .destructive) {
        //
      }
    }
  }

  extension UserProfileUpdateProfileView {
    
    func save() async {
      
    }
    
  }

  #Preview {
    UserProfileUpdateProfileView(user: .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
