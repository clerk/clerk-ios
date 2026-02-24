//
//  UserProfileView.swift
//  Clerk
//

// swiftlint:disable file_length

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
///
/// Embedded in a parent `NavigationStack`:
///
/// ```swift
/// struct ContentView: View {
///   @State private var path = NavigationPath()
///
///   var body: some View {
///     NavigationStack(path: $path) {
///       HomeView()
///         .navigationDestination(for: AppRoute.self) { route in
///           switch route {
///           case .profile:
///             UserProfileView(isDismissable: false, navigationPath: $path)
///           }
///         }
///     }
///   }
/// }
/// ```
public struct UserProfileView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let isDismissable: Bool
  private let navigationPath: Binding<NavigationPath>?

  @State private var updateProfileIsPresented = false
  @State private var accountSwitcherHeight: CGFloat = 400
  @State private var embeddedPushCount = 0
  @State private var internalPath = NavigationPath()
  @State private var navigation = UserProfileSheetNavigation()
  @State private var codeLimiter = CodeLimiter()
  @State private var error: Error?

  /// Creates a new user profile view.
  ///
  /// - Parameters:
  ///   - isDismissable: Whether the view can be dismissed by the user.
  ///   When `true`, a dismiss button appears in the navigation bar and the view
  ///   can be used in sheets or other dismissable contexts. When `false`, no
  ///   dismiss button is shown, making it suitable for full-screen usage.
  ///   Defaults to `true`.
  ///   - navigationPath: An optional binding to a parent `NavigationPath`. When provided,
  ///   the view skips creating its own `NavigationStack` and pushes destinations onto the
  ///   parent's path instead. Use this when embedding `UserProfileView` inside your own
  ///   `NavigationStack` to avoid nested navigation stacks. Defaults to `nil`.
  public init(isDismissable: Bool = true, navigationPath: Binding<NavigationPath>? = nil) {
    self.isDismissable = isDismissable
    self.navigationPath = navigationPath
  }

  public var body: some View {
    if let user = clerk.user {
      Group {
        if navigationPath == nil {
          NavigationStack(path: $internalPath) {
            profileContent(user: user)
          }
        } else {
          profileContent(user: user)
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
      .onChange(of: navigationPath?.wrappedValue.count) { oldValue, newValue in
        guard let oldValue, let newValue else {
          embeddedPushCount = 0
          return
        }

        if newValue < oldValue {
          embeddedPushCount = max(embeddedPushCount - (oldValue - newValue), 0)
        }
      }
      .taskOnce {
        await clerk.telemetry.record(
          TelemetryEvents.viewDidAppear(
            "UserProfileView",
            payload: [
              "isDismissable": .bool(isDismissable),
              "isEmbedded": .bool(navigationPath != nil),
            ]
          )
        )
      }
      .environment(navigation)
      .environment(codeLimiter)
      .environment(\.userProfileRouter, router)
    }
  }

  private var router: UserProfileRouter {
    UserProfileRouter(
      push: { destination in
        if let navigationPath {
          navigationPath.wrappedValue.append(destination)
          embeddedPushCount += 1
        } else {
          internalPath.append(destination)
        }
      },
      popToRoot: {
        let includingSelf = clerk.user == nil
        if let navigationPath {
          let currentCount = navigationPath.wrappedValue.count
          let requestedRemovals = embeddedPushCount + (includingSelf ? 1 : 0)
          let entriesToRemove = min(max(requestedRemovals, 0), currentCount)
          if entriesToRemove > 0 {
            navigationPath.wrappedValue.removeLast(entriesToRemove)
          }
          embeddedPushCount = 0
        } else {
          internalPath = NavigationPath()
        }
      }
    )
  }

  private func profileContent(user: User) -> some View {
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
    .navigationDestination(for: Destination.self) { destination in
      destination.view
        .environment(navigation)
        .environment(codeLimiter)
        .environment(\.userProfileRouter, router)
    }
  }
}

// MARK: - Subviews

extension UserProfileView {
  private var profileSection: some View {
    VStack(spacing: 0) {
      row(icon: "icon-profile", text: "Manage account") {
        router.push(.profileDetail)
      }

      row(icon: "icon-security", text: "Security") {
        router.push(.security)
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
        if clerk.auth.sessions.count > 1 {
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
    guard let user = clerk.user else { return }
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
        Text("Edit profile", bundle: .module)
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
  enum Destination: Hashable, Sendable {
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
    .environment(UserProfileSheetNavigation())
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
    .environment(UserProfileSheetNavigation())
    .environment(\.clerkTheme, .clerk)
}

#endif
