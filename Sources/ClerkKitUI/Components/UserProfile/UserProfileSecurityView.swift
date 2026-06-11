//
//  UserProfileSecurityView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileSecurityView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileSheetNavigation.self) private var navigation
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  private var environment: Clerk.Environment? {
    clerk.environment
  }

  private var shouldShowDevices: Bool {
    guard let user else { return false }
    return (clerk.sessionsByUserId[user.id] ?? []).contains { $0.latestActivity != nil }
  }

  var body: some View {
    @Bindable var navigation = navigation

    Group {
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

            if shouldShowDevices {
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
    }
    .securedByClerkFooter()
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
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
    #if os(macOS)
    .frame(minWidth: 460, maxWidth: 620, alignment: .leading)
    #endif
  }
}

#Preview {
  NavigationStack {
    UserProfileSecurityView()
  }
  .clerkPreview()
  .environment(UserProfileSheetNavigation())
  .environment(\.clerkTheme, .clerk)
}

#endif
