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

    @State private var updateProfileIsPresented = false
    @State private var accountSwitcherHeight: CGFloat = 400
    @State private var sharedState = SharedState()
    @State private var error: Error?

    let isDismissable: Bool

    public init(isDismissable: Bool = false) {
      self.isDismissable = isDismissable
    }

    var user: User? {
      clerk.user
    }

    @ViewBuilder
    private func userProfileHeader(_ user: User) -> some View {
      VStack(spacing: 12) {
        KFImage(URL(string: user.imageUrl))
          .resizable()
          .placeholder {
            Image("icon-profile", bundle: .module)
              .resizable()
              .scaledToFit()
              .foregroundStyle(theme.colors.primary.gradient)
          }
          .fade(duration: 0.25)
          .scaledToFill()
          .frame(width: 96, height: 96)
          .clipShape(.circle)

        if let fullName = user.fullName {
          Text(fullName)
            .font(theme.fonts.title2)
            .fontWeight(.bold)
            .frame(minHeight: 28)
        }

        Button {
          updateProfileIsPresented = true
        } label: {
          Text("Update profile", bundle: .module)
        }
        .buttonStyle(.secondary(config: .init(size: .small)))
        .simultaneousGesture(TapGesture())
      }
      .padding(32)
      .frame(maxWidth: .infinity)
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
      if let user {
        NavigationStack(path: $sharedState.path) {
          VStack(spacing: 0) {
            ScrollView {
              VStack(spacing: 0) {
                userProfileHeader(user)

                VStack(spacing: 48) {
                  VStack(spacing: 0) {
                    row(icon: "icon-profile", text: "Profile") {
                      sharedState.path.append(Destination.profileDetail)
                    }

                    row(icon: "icon-security", text: "Security") {
                      sharedState.path.append(Destination.security)
                    }
                  }
                  .background(theme.colors.background)
                  .overlay(alignment: .top) {
                    Rectangle()
                      .frame(height: 1)
                      .foregroundStyle(theme.colors.border)
                  }

                  VStack(spacing: 0) {
                    if clerk.environment.mutliSessionModeIsEnabled {
                      if let activeSessions = clerk.client?.activeSessions, activeSessions.count > 1 {
                        row(icon: "icon-switch", text: "Switch account") {
                          sharedState.accountSwitcherIsPresented = true
                        }
                      }

                      row(icon: "icon-plus", text: "Add account") {
                        sharedState.authViewIsPresented = true
                      }
                    }

                    row(icon: "icon-sign-out", text: "Sign out") {
                      guard let sessionId = clerk.session?.id else { return }
                      await signOut(sessionId: sessionId)
                    }
                  }
                  .background(theme.colors.background)
                  .overlay(alignment: .top) {
                    Rectangle()
                      .frame(height: 1)
                      .foregroundStyle(theme.colors.border)
                  }
                }
              }
            }
            .background(theme.colors.backgroundSecondary)

            SecuredByClerkFooter()
          }
          .animation(.default, value: user)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .principal) {
              Text("Account", bundle: .module)
                .font(theme.fonts.headline)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.text)
            }

            if isDismissable {
              ToolbarItem(placement: .topBarTrailing) {
                DismissButton()
              }
            }
          }
          .navigationDestination(for: Destination.self) {
            $0.view
          }
        }
        .tint(theme.colors.primary)
        .background(theme.colors.background)
        .clerkErrorPresenting($error)
        .sheet(isPresented: $sharedState.accountSwitcherIsPresented) {
          UserButtonAccountSwitcher(contentHeight: $accountSwitcherHeight)
            .presentationDetents([.height(accountSwitcherHeight)])
        }
        .sheet(isPresented: $updateProfileIsPresented) {
          UserProfileUpdateProfileView(user: user)
        }
        .sheet(isPresented: $sharedState.authViewIsPresented) {
          AuthView()
            .interactiveDismissDisabled()
        }
        .task {
          for await event in clerk.authEventEmitter.events {
            switch event {
            case .signInCompleted, .signUpCompleted:
              sharedState.authViewIsPresented = false
            }
          }
        }
        .task(id: user) {
          await getSessionsOnAllDevices()
        }
        .task {
          try? await Clerk.Environment.get()
        }
        .task {
          try? await Client.get()
        }
        .environment(\.userProfileSharedState, sharedState)
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
        ClerkLogger.error("Failed to sign out", error: error)
      }
    }

    func getSessionsOnAllDevices() async {
      guard let user else { return }
      do {
        try await user.getSessions()
      } catch is CancellationError {
        ClerkLogger.error("Failed to get sessions on all devices", error: error)
      } catch {
        self.error = error
        ClerkLogger.error("Failed to get sessions on all devices", error: error)
      }
    }

  }

  extension UserProfileView {
    enum Destination: Hashable {
      case profileDetail
      case security

      @ViewBuilder
      var view: some View {
        switch self {
        case .profileDetail:
          UserProfileDetailView()
        case .security:
          UserProfileSecurityView()
        }
      }
    }
  }

  extension UserProfileView {
    @Observable
    class SharedState {
      var path = NavigationPath()
      var lastCodeSentAt: [String: Date] = [:]
      var accountSwitcherIsPresented = false
      var authViewIsPresented = false
      var chooseMfaTypeIsPresented = false
      var presentedAddMfaType: UserProfileAddMfaView.PresentedView?
    }
  }

  extension EnvironmentValues {
    @Entry var userProfileSharedState = UserProfileView.SharedState()
  }

  #Preview("Dismissable") {
    UserProfileView(isDismissable: true)
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

  #Preview("Not dismissable") {
    UserProfileView()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
