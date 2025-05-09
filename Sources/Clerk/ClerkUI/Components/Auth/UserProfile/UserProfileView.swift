//
//  UserProfileView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/8/25.
//

#if os(iOS)

  import Kingfisher
  import SwiftUI

  public struct UserProfileView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var authViewIsPresented = false
    @State private var accountSwitcherIsPresented = false
    @State private var error: Error?

    let isInSheet: Bool

    public init(isInSheet: Bool = false) {
      self.isInSheet = isInSheet
    }

    var user: User? {
      clerk.user
    }

    @ViewBuilder
    private func userProfileHeader(_ user: User) -> some View {
      VStack(spacing: 12) {
        KFImage(URL(string: user.imageUrl))
          .resizable()
          .placeholder { theme.colors.primary }
          .fade(duration: 0.25)
          .scaledToFit()
          .frame(width: 96, height: 96)
          .clipShape(.circle)

        if let fullName = user.fullName {
          Text(fullName)
            .font(theme.fonts.title2)
            .fontWeight(.bold)
            .frame(minHeight: 28)
        }

        Button {
          //
        } label: {
          Text("Update profile", bundle: .module)
        }
        .buttonStyle(.secondary(config: .init(size: .small)))
        .simultaneousGesture(TapGesture())
      }
      .padding(32)
      .frame(maxWidth: .infinity)
      .background(theme.colors.backgroundSecondary)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
    }

    @ViewBuilder
    private func row(
      icon: String,
      text: LocalizedStringKey,
      action: @escaping () async -> Void
    ) -> some View {
      AsyncButton {
        await action()
      } label: { isRunning in
        UserProfileRowView(icon: icon, text: text)
          .overlayProgressView(isActive: isRunning)
      }
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
      .buttonStyle(.pressedBackground)
      .simultaneousGesture(TapGesture())
    }

    public var body: some View {
      NavigationStack {
        VStack(spacing: 0) {
          if isInSheet {
            HStack {
              DismissButton()
                .hidden()
              Spacer()
              Text("Account", bundle: .module)
                .font(theme.fonts.headline)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.text)
                .frame(minHeight: 22)
              Spacer()
              DismissButton()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 16)
            .background(theme.colors.backgroundSecondary)
          }

          ScrollView {
            VStack(spacing: 0) {
              if let user {
                userProfileHeader(user)
              }

              row(icon: "icon-profile", text: "Profile") {
                //
              }

              row(icon: "icon-security", text: "Security") {
                //
              }

            }
          }
          .scrollBounceBehavior(isInSheet ? .basedOnSize : .automatic)

          VStack(spacing: 0) {
            if clerk.environment.mutliSessionModeIsEnabled {
              if let activeSessions = clerk.client?.activeSessions, activeSessions.count > 1 {
                row(icon: "icon-switch", text: "Switch account") {
                  accountSwitcherIsPresented = true
                }
              }

              row(icon: "icon-plus", text: "Add account") {
                authViewIsPresented = true
              }
            }

            row(icon: "icon-sign-out", text: "Sign out") {
              guard let sessionId = clerk.session?.id else { return }
              await signOut(sessionId: sessionId)
            }
          }
          .background(theme.colors.backgroundSecondary)
          .overlay(alignment: .top) {
            Rectangle()
              .frame(height: 1)
              .foregroundStyle(theme.colors.border)
          }

          SecuredByClerkView()
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(theme.colors.backgroundSecondary)
        }
        .animation(.default, value: user)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(isInSheet ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(theme.colors.backgroundSecondary, for: .navigationBar)
        .toolbar {
          if !isInSheet {
            ToolbarItem(placement: .principal) {
              Text("Account", bundle: .module)
                .font(theme.fonts.headline)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.text)
            }
          }
        }
      }
      .animation(.default) {
        $0.blur(radius: accountSwitcherIsPresented ? 12 : 0)
      }
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .sheet(isPresented: $accountSwitcherIsPresented) {
        UserButtonAccountSwitcher()
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.hidden)
      }
      .sheet(isPresented: $authViewIsPresented) {
        AuthView()
          .interactiveDismissDisabled()
      }
      .task {
        for await event in clerk.authEventEmitter.events {
          switch event {
          case .signInCompleted, .signUpCompleted:
            authViewIsPresented = false
          }
        }
      }
    }
  }

  extension UserProfileView {

    func signOut(sessionId: String) async {
      do {
        try await clerk.signOut(sessionId: sessionId)
        if clerk.session == nil {
          dismiss()
        }
      } catch {
        self.error = error
      }
    }

  }

  #Preview("In sheet") {
    UserProfileView(isInSheet: true)
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
    //      .environment(\.locale, .init(identifier: "es"))
    //      .environment(\.layoutDirection, .rightToLeft)
  }

  #Preview("Not in sheet") {
    UserProfileView()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
