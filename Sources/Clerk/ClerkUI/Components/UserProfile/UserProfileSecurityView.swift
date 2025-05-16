//
//  UserProfileSecurityView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

  import Factory
  import SwiftUI

  struct UserProfileSecurityView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    @State private var error: Error?

    var user: User? {
      clerk.user
    }

    var environment: Clerk.Environment {
      clerk.environment
    }

    var body: some View {
      VStack(spacing: 0) {
        if let user {
          ScrollView {
            VStack(spacing: 0) {
              if environment.isPasswordEnabled {
                UserProfilePasswordSection()
              }

              if environment.isMfaEnabled {
                UserProfileMfaSection()
              }

              if !clerk.sessionsByUserId.isEmpty {
                UserProfileDevicesSection()
                  .transition(.opacity.animation(.default))
              }
              
              if environment.isDeleteSelfEnabled {
                UserProfileDeleteAccountSection()
              }
            }
          }
          .background(theme.colors.backgroundSecondary)
        }

        SecuredByClerkView()
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(theme.colors.backgroundSecondary)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Security", bundle: .module)
            .font(theme.fonts.headline)
            .fontWeight(.semibold)
            .foregroundStyle(theme.colors.text)
        }
      }
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
    }
  }

  #Preview {
    NavigationStack {
      UserProfileSecurityView()
    }
    .environment(\.clerk, .mock)
    .environment(\.clerkTheme, .clerk)
  }

#endif
