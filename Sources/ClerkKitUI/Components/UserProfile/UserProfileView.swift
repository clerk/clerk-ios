//
//  UserProfileView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/8/25.
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

/// A comprehensive user profile view that displays user information and account management options.
///
/// ``UserProfileView`` provides an interface for users to view and manage their profile,
/// including personal information, security settings, account switching, and sign-out functionality.
///
/// ## Usage
///
/// As a full-screen profile view:
///
/// ```swift
/// struct ProfileView: View {
///   @Environment(Clerk.self) private var clerk
///
///   var body: some View {
///     Group {
///       if clerk.user != nil {
///         UserProfileView(isDismissable: false)
///       } else {
///         AuthView(isDismissable: false)
///       }
///     }
///   }
/// }
/// ```
///
/// As a dismissable sheet:
///
/// ```swift
/// struct MainView: View {
///   @State private var profileIsPresented = false
///
///   var body: some View {
///     Button("Show Profile") {
///       profileIsPresented = true
///     }
///     .sheet(isPresented: $profileIsPresented) {
///       UserProfileView()
///     }
///   }
/// }
/// ```
public struct UserProfileView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  let isDismissable: Bool

  @State private var updateProfileIsPresented = false
  @State private var accountSwitcherHeight: CGFloat = 400
  @State private var navigation = UserProfileNavigation()
  @State private var codeLimiter = CodeLimiter()
  @State private var error: Error?

  /// Creates a new user profile view.
  ///
  /// - Parameter isDismissable: Whether the view can be dismissed by the user.
  ///   When `true`, a dismiss button appears in the navigation bar and the view
  ///   can be used in sheets or other dismissable contexts. When `false`, no
  ///   dismiss button is shown, making it suitable for full-screen usage.
  ///   Defaults to `true`.
  public init(isDismissable: Bool = true) {
    self.isDismissable = isDismissable
  }

  var user: User? {
    clerk.user
  }

  public var body: some View {
    if let user {
      NavigationStack(path: $navigation.path) {
        VStack(spacing: 0) {
          ScrollView {
            LazyVStack(spacing: 0) {
              UserProfileHeaderView(
                user: user,
                onUpdateProfile: {
                  updateProfileIsPresented = true
                }
              )

              VStack(spacing: 48) {
                profileSection

                accountSection
              }
            }
          }
          .background(theme.colors.muted)

          SecuredByClerkFooter()
        }
        .animation(.default, value: user)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .principal) {
            Text("Account", bundle: .module)
              .font(theme.fonts.headline)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.foreground)
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
      .presentationBackground(theme.colors.background)
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .sheet(isPresented: $navigation.accountSwitcherIsPresented) {
        UserButtonAccountSwitcher(contentHeight: $accountSwitcherHeight)
          .presentationDetents([.height(accountSwitcherHeight)])
      }
      .sheet(isPresented: $updateProfileIsPresented) {
        UserProfileUpdateProfileView(user: user)
      }
      .sheet(isPresented: $navigation.authViewIsPresented) {
        AuthView()
          .interactiveDismissDisabled()
      }
      .task {
        for await event in clerk.auth.events {
          switch event {
          case .signInCompleted, .signUpCompleted:
            navigation.authViewIsPresented = false
          default:
            break
          }
        }
      }
      .task(id: user) {
        await getSessionsOnAllDevices()
      }
      .task {
        _ = try? await clerk.refreshEnvironment()
      }
      .task {
        _ = try? await clerk.refreshClient()
      }
      .taskOnce {
        await clerk.telemetry.record(
          TelemetryEvents.viewDidAppear(
            "UserProfileView",
            payload: ["isDismissable": .bool(isDismissable)]
          )
        )
      }
      .environment(navigation)
      .environment(codeLimiter)
    }
  }
}

// MARK: - Subviews

extension UserProfileView {
  private var profileSection: some View {
    VStack(spacing: 0) {
      row(icon: "icon-profile", text: "Profile") {
        navigation.path.append(Destination.profileDetail)
      }

      row(icon: "icon-security", text: "Security") {
        navigation.path.append(Destination.security)
      }
    }
    .background(theme.colors.background)
    .overlay(alignment: .top) {
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(theme.colors.border)
    }
  }

  private var accountSection: some View {
    VStack(spacing: 0) {
      if clerk.environment?.mutliSessionModeIsEnabled == true {
        if let activeSessions = clerk.client?.activeSessions, activeSessions.count > 1 {
          row(icon: "icon-switch", text: "Switch account") {
            navigation.accountSwitcherIsPresented = true
          }
        }

        row(icon: "icon-plus", text: "Add account") {
          navigation.authViewIsPresented = true
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
}

// MARK: - Actions

extension UserProfileView {
  func signOut(sessionId: String) async {
    do {
      try await clerk.auth.signOut(sessionId: sessionId)
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
    } catch {
      if error.isCancellationError {
        ClerkLogger.error("Get sessions on all devices cancelled.", error: error)
      } else {
        self.error = error
        ClerkLogger.error("Failed to get sessions on all devices", error: error)
      }
    }
  }
}

// MARK: - UserProfileHeaderView

private struct UserProfileHeaderView: View {
  @Environment(\.clerkTheme) private var theme

  let user: User
  let onUpdateProfile: () -> Void

  var body: some View {
    let fullName = user.fullName
    let hasFullName = fullName != nil

    VStack(spacing: 12) {
      LazyImage(url: URL(string: user.imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          Image("icon-profile", bundle: .module)
            .resizable()
            .scaledToFit()
            .foregroundStyle(theme.colors.primary.gradient)
            .opacity(0.5)
        }
      }
      .frame(width: 96, height: 96)
      .clipShape(.circle)
      .transition(.opacity.animation(.easeInOut(duration: 0.25)))

      VStack(spacing: 0) {
        if let fullName {
          Text(fullName)
            .font(theme.fonts.title2)
            .fontWeight(.bold)
            .frame(minHeight: 28)
            .foregroundStyle(theme.colors.foreground)
        }

        if let username = user.username, !username.isEmptyTrimmed {
          Text(username)
            .font(
              hasFullName
                ? theme.fonts.subheadline
                : theme.fonts.title2
            )
            .fontWeight(hasFullName ? .regular : .bold)
            .frame(minHeight: hasFullName ? nil : 28)
            .foregroundStyle(hasFullName ? theme.colors.mutedForeground : theme.colors.foreground)
        }
      }

      Button {
        onUpdateProfile()
      } label: {
        Text("Update profile", bundle: .module)
      }
      .buttonStyle(.secondary(config: .init(size: .small)))
      .simultaneousGesture(TapGesture())
    }
    .padding(32)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Destination

extension UserProfileView {
  enum Destination: Hashable {
    case profileDetail
    case security

    @MainActor
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

#Preview("Dismissable") {
  UserProfileView()
    .environment(
      Clerk.preview { builder in
        builder.services.clientService.getHandler = {
          try? await Task.sleep(for: .seconds(1))
          return Client.mock
        }

        builder.services.environmentService.getHandler = {
          try? await Task.sleep(for: .seconds(1))
          return Clerk.Environment.mock
        }

        builder.services.userService.getSessionsHandler = { _ in
          try? await Task.sleep(for: .seconds(1))
          return [Session.mock, Session.mock2]
        }
      }
    )
    .environment(AuthState())
    .environment(UserProfileNavigation())
    .environment(\.clerkTheme, .clerk)
}

#Preview("Not dismissable") {
  UserProfileView(isDismissable: false)
    .environment(
      Clerk.preview { builder in
        builder.services.clientService.getHandler = {
          try? await Task.sleep(for: .seconds(1))
          return Client.mock
        }

        builder.services.environmentService.getHandler = {
          try? await Task.sleep(for: .seconds(1))
          return Clerk.Environment.mock
        }

        builder.services.userService.getSessionsHandler = { _ in
          try? await Task.sleep(for: .seconds(1))
          return [Session.mock, Session.mock2]
        }
      }
    )
    .environment(AuthState())
    .environment(UserProfileNavigation())
    .environment(\.clerkTheme, .clerk)
}

#endif
