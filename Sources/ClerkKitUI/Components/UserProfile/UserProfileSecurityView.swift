//
//  UserProfileSecurityView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileSecurityView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileNavigation.self) private var navigation

  @State private var error: Error?

  var user: User? {
    clerk.user
  }

  var environment: Clerk.Environment? {
    clerk.environment
  }

  var body: some View {
    @Bindable var navigation = navigation

    VStack(spacing: 0) {
      if let user {
        ScrollView {
          VStack(spacing: 0) {
            if environment?.passwordIsEnabled == true {
              UserProfilePasswordSection()
            }

            if environment?.passkeyIsEnabled == true {
              UserProfilePasskeySection()
            }

            if environment?.mfaIsEnabled == true {
              UserProfileMfaSection()
            }

            if let sessions = clerk.sessionsByUserId[user.id],
               !sessions.filter({ $0.latestActivity != nil }).isEmpty
            {
              UserProfileDevicesSection()
            }

            if environment?.deleteSelfIsEnabled == true {
              UserProfileDeleteAccountSection()
            }
          }
          .animation(.default, value: user)
          .animation(.default, value: clerk.sessionsByUserId)
          .animation(.default, value: environment)
        }
        .background(theme.colors.muted)
      }

      SecuredByClerkFooter()
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Security", bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .task {
      _ = try? await user?.getSessions()
    }
    .task {
      _ = try? await clerk.refreshClient()
    }
    .sheet(item: $navigation.presentedAddMfaType) {
      $0.view
    }
  }
}

#Preview {
  NavigationStack {
    UserProfileSecurityView()
  }
  .clerkPreview()
  .environment(\.clerkTheme, .clerk)
}

#endif
