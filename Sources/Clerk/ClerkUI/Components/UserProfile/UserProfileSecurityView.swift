//
//  UserProfileSecurityView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

  import FactoryKit
  import SwiftUI

  struct UserProfileSecurityView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.userProfileSharedState) private var sharedState

    @State private var error: Error?

    var user: User? {
      clerk.user
    }

    var environment: Clerk.Environment {
      clerk.environment
    }

    var body: some View {
      @Bindable var sharedState = sharedState
      
      VStack(spacing: 0) {
        if let user {
          ScrollView {
            VStack(spacing: 0) {
              if environment.passwordIsEnabled {
                UserProfilePasswordSection()
              }
              
              if environment.passkeyIsEnabled {
                UserProfilePasskeySection()
              }
              
              if environment.mfaIsEnabled {
                UserProfileMfaSection()
              }

              if !clerk.sessionsByUserId.isEmpty {
                UserProfileDevicesSection()
              }
              
              if environment.deleteSelfIsEnabled {
                UserProfileDeleteAccountSection()
              }
            }
            .animation(.default, value: user)
            .animation(.default, value: clerk.sessionsByUserId)
            .animation(.default, value: environment)
          }
          .background(theme.colors.backgroundSecondary)
        }

        SecuredByClerkFooter()
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
      .presentationBackground(theme.colors.background)
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .task {
        try? await user?.getSessions()
      }
      .task {
        try? await Client.get()
      }
      .sheet(item: $sharedState.presentedAddMfaType) {
        $0.view
      }
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
