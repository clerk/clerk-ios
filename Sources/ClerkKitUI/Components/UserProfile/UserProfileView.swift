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
///
/// With custom rows:
///
/// ```swift
/// enum ProfileRoute: Hashable {
///   case billing
///   case preferences
/// }
///
/// UserProfileView()
///   .userProfileRows([
///     .init(route: .billing, title: "Billing", icon: .asset(name: "icon-card"), placement: .after(.security)),
///     .init(route: .preferences, title: "Preferences", icon: .system(name: "gear"), placement: .before(.signOut)),
///   ])
///   .userProfileDestination { (route: ProfileRoute) in
///     switch route {
///     case .billing:
///       BillingView()
///     case .preferences:
///       PreferencesView()
///     }
///   }
/// ```
///
/// Custom destination views can access programmatic navigation through
/// ``UserProfileNavigator`` when needed.
public struct UserProfileView<Route: Hashable, Destination: View>: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let isDismissable: Bool
  private let navigationPath: Binding<NavigationPath>?
  private let customRows: [UserProfileCustomRow<Route>]
  private let customDestination: (@MainActor (Route) -> Destination)?
  private let oauthConfig: UserProfileOAuthConfiguration

  @State private var updateProfileIsPresented = false
  @State private var accountSwitcherHeight: CGFloat = 400
  @State private var initialPathCount = 0
  @State private var internalPath = NavigationPath()
  @State private var sheetNavigation = UserProfileSheetNavigation()
  @State private var codeLimiter = CodeLimiter()
  @State private var error: Error?

  init(
    isDismissable: Bool,
    navigationPath: Binding<NavigationPath>?,
    customRows: [UserProfileCustomRow<Route>],
    customDestination: (@MainActor (Route) -> Destination)?,
    oauthConfig: UserProfileOAuthConfiguration
  ) {
    self.isDismissable = isDismissable
    self.navigationPath = navigationPath
    self.customRows = customRows
    self.customDestination = customDestination
    self.oauthConfig = oauthConfig
  }

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
  public init(
    isDismissable: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil
  ) where Route == Never, Destination == EmptyView {
    self.init(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: [],
      customDestination: nil,
      oauthConfig: .init()
    )
  }

  public var body: some View {
    if let user = clerk.user {
      Group {
        if navigationPath == nil {
          NavigationStack(path: $internalPath) {
            profileContent(user: user)
              .navigationDestination(for: Route.self) { route in
                view(for: route)
                  .environment(sheetNavigation)
                  .environment(codeLimiter)
                  .environment(
                    UserProfileNavigator(
                      push: navigateToCustom,
                      popToRoot: { dismissAction(.popToRoot) }
                    )
                  )
                  .environment(
                    UserProfileBuiltInRouter(
                      push: navigateToBuiltIn,
                      dismissAction: dismissAction
                    )
                  )
              }
          }
        } else {
          profileContent(user: user)
        }
      }
      .tint(theme.colors.primary)
      .presentationBackground(theme.colors.background)
      .background(theme.colors.background)
      .onFirstAppear {
        initialPathCount = navigationPath?.wrappedValue.count ?? 0
      }
      .clerkErrorPresenting($error)
      .sheet(isPresented: $sheetNavigation.accountSwitcherIsPresented) {
        UserButtonAccountSwitcher(contentHeight: $accountSwitcherHeight)
          .presentationDetents([.height(accountSwitcherHeight)])
      }
      .sheet(isPresented: $updateProfileIsPresented) {
        UserProfileUpdateProfileView(user: user)
      }
      .sheet(isPresented: $sheetNavigation.authViewIsPresented) {
        AuthView()
          .interactiveDismissDisabled()
      }
      .task {
        for await event in clerk.auth.events {
          switch event {
          case .signInCompleted, .signUpCompleted:
            guard clerk.session?.pendingTasks.isEmpty != false else { break }
            sheetNavigation.authViewIsPresented = false
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
            payload: [
              "isDismissable": .bool(isDismissable),
              "isEmbedded": .bool(navigationPath != nil),
            ]
          )
        )
      }
      .environment(sheetNavigation)
      .environment(codeLimiter)
      .environment(
        UserProfileBuiltInRouter(
          push: navigateToBuiltIn,
          dismissAction: dismissAction
        )
      )
    }
  }

  private func navigateToBuiltIn(_ destination: UserProfileBuiltInDestination) {
    if let navigationPath {
      navigationPath.wrappedValue.append(destination)
    } else {
      internalPath.append(destination)
    }
  }

  private func navigateToCustom(_ route: Route) {
    if let navigationPath {
      navigationPath.wrappedValue.append(route)
    } else {
      internalPath.append(route)
    }
  }

  private func dismissAction(_ action: UserProfileDismissAction) {
    let extraRemoval = action == .exitUserProfile ? 1 : 0

    if let navigationPath {
      let currentCount = navigationPath.wrappedValue.count
      let entriesToRemove = min(max(currentCount - initialPathCount + extraRemoval, 0), currentCount)
      navigationPath.wrappedValue.removeLast(entriesToRemove)
    } else {
      internalPath = NavigationPath()
    }
  }

  private var accountBuiltInRows: [UserProfileRow] {
    var rows: [UserProfileRow] = []

    if clerk.environment?.mutliSessionModeIsEnabled == true {
      if clerk.auth.sessions.count > 1 {
        rows.append(.switchAccount)
      }

      rows.append(.addAccount)
    }

    rows.append(.signOut)

    return rows
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
            section(rows: renderedRows(builtInRows: [.manageAccount, .security], in: .profile))
            section(rows: renderedRows(builtInRows: accountBuiltInRows, in: .account))
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
    .navigationDestination(for: UserProfileBuiltInDestination.self) { destination in
      view(for: destination)
        .environment(sheetNavigation)
        .environment(codeLimiter)
        .environment(
          UserProfileNavigator(
            push: navigateToCustom,
            popToRoot: { dismissAction(.popToRoot) }
          )
        )
        .environment(
          UserProfileBuiltInRouter(
            push: navigateToBuiltIn,
            dismissAction: dismissAction
          )
        )
        .environment(\.clerkUserProfileOAuthConfig, oauthConfig)
    }
  }
}

// MARK: - View Modifiers

extension UserProfileView {
  /// Replaces the custom rows rendered on the root user profile screen.
  public func userProfileRows(
    _ rows: [UserProfileCustomRow<Route>]
  ) -> UserProfileView<Route, Destination> {
    UserProfileView<Route, Destination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: rows,
      customDestination: customDestination,
      oauthConfig: oauthConfig
    )
  }

  /// Configures OAuth settings per provider for built-in connected account flows.
  public func userProfileOAuthConfig(
    _ configs: [OAuthProviderConfig]
  ) -> UserProfileView<Route, Destination> {
    UserProfileView<Route, Destination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: customRows,
      customDestination: customDestination,
      oauthConfig: .init(configs)
    )
  }
}

extension UserProfileView where Destination == EmptyView {
  /// Sets the custom destination builder used by custom user profile rows.
  ///
  /// This modifier is used when `UserProfileView` manages its own `NavigationStack`
  /// (i.e., no `navigationPath` is provided). When you provide a `navigationPath`,
  /// register your own `.navigationDestination(for:)` on the parent stack instead.
  public func userProfileDestination<NewDestination: View>(
    @ViewBuilder _ destination: @escaping @MainActor (Route) -> NewDestination
  ) -> UserProfileView<Route, NewDestination> {
    UserProfileView<Route, NewDestination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: customRows,
      customDestination: destination,
      oauthConfig: oauthConfig
    )
  }
}

extension UserProfileView where Route == Never, Destination == EmptyView {
  /// Sets the custom rows rendered on the root user profile screen.
  public func userProfileRows<NewRoute: Hashable>(
    _ rows: [UserProfileCustomRow<NewRoute>]
  ) -> UserProfileView<NewRoute, EmptyView> {
    UserProfileView<NewRoute, EmptyView>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: rows,
      customDestination: nil,
      oauthConfig: oauthConfig
    )
  }

  /// Sets the custom destination builder used by custom user profile rows.
  ///
  /// This modifier is used when `UserProfileView` manages its own `NavigationStack`
  /// (i.e., no `navigationPath` is provided). When you provide a `navigationPath`,
  /// register your own `.navigationDestination(for:)` on the parent stack instead.
  public func userProfileDestination<NewRoute: Hashable, NewDestination: View>(
    for _: NewRoute.Type = NewRoute.self,
    @ViewBuilder _ destination: @escaping @MainActor (NewRoute) -> NewDestination
  ) -> UserProfileView<NewRoute, NewDestination> {
    UserProfileView<NewRoute, NewDestination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: [],
      customDestination: destination,
      oauthConfig: oauthConfig
    )
  }
}

// MARK: - Subviews

extension UserProfileView {
  fileprivate func section(rows: [UserProfileListRow<Route>]) -> some View {
    VStack(spacing: 0) {
      ForEach(rows) { row in
        rowView(row)
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
  fileprivate func rowView(_ listRow: UserProfileListRow<Route>) -> some View {
    switch listRow {
    case .builtIn(let builtInRow):
      builtInRowView(builtInRow)
    case .custom(let customRow, _):
      row(icon: customRow.icon, text: customRow.title, bundle: nil) {
        navigateToCustom(customRow.route)
      }
    }
  }

  fileprivate func builtInRowView(_ rowType: UserProfileRow) -> some View {
    row(icon: rowType.icon, text: rowType.title) {
      switch rowType {
      case .manageAccount:
        navigateToBuiltIn(.manageAccount)
      case .security:
        navigateToBuiltIn(.security)
      case .switchAccount:
        sheetNavigation.accountSwitcherIsPresented = true
      case .addAccount:
        sheetNavigation.authViewIsPresented = true
      case .signOut:
        guard let sessionId = clerk.session?.id else { return }
        await signOut(sessionId: sessionId)
      }
    }
  }

  fileprivate func row(
    icon: String,
    text: LocalizedStringKey,
    bundle: Bundle? = .module,
    action: @escaping () async -> Void
  ) -> some View {
    row(icon: .asset(name: icon), text: text, bundle: bundle, action: action)
  }

  fileprivate func row(
    icon: UserProfileRowIcon,
    text: LocalizedStringKey,
    bundle: Bundle? = .module,
    action: @escaping () async -> Void
  ) -> some View {
    AsyncButton {
      await action()
    } label: { isRunning in
      UserProfileRowView(icon: icon, text: text, bundle: bundle)
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

  @ViewBuilder
  fileprivate func view(
    for destination: UserProfileBuiltInDestination
  ) -> some View {
    switch destination {
    case .manageAccount:
      UserProfileDetailView()
    case .security:
      UserProfileSecurityView()
    }
  }

  @ViewBuilder
  fileprivate func view(for route: Route) -> some View {
    if let customDestination {
      customDestination(route)
    } else {
      EmptyView()
        .onAppear {
          ClerkLogger.error("No destination registered for custom route \(route). Use .userProfileDestination to provide one.")
        }
    }
  }
}

// MARK: - Ordering

extension UserProfileView {
  fileprivate func renderedRows(
    builtInRows: [UserProfileRow],
    in section: UserProfileSection
  ) -> [UserProfileListRow<Route>] {
    let sectionCustomRows = customRows.filter { $0.placement.section == section }

    let sectionStartRows = sectionCustomRows.filter { $0.placement.isSectionStart }
    let sectionEndRows = sectionCustomRows.filter { $0.placement.isSectionEnd }

    let rowsBeforeAnchor = sectionCustomRows.reduce(into: [UserProfileRow: [UserProfileCustomRow<Route>]]()) { result, customRow in
      guard case .before(let anchor) = customRow.placement else { return }
      result[anchor, default: []].append(customRow)
    }

    let rowsAfterAnchor = sectionCustomRows.reduce(into: [UserProfileRow: [UserProfileCustomRow<Route>]]()) { result, customRow in
      guard case .after(let anchor) = customRow.placement else { return }
      result[anchor, default: []].append(customRow)
    }

    var routeOccurrences = [AnyHashable: Int]()

    func nextCustomRow(_ customRow: UserProfileCustomRow<Route>) -> UserProfileListRow<Route> {
      let key = AnyHashable(customRow.route)
      let occurrence = routeOccurrences[key, default: 0]
      routeOccurrences[key] = occurrence + 1
      return .custom(customRow, occurrence: occurrence)
    }

    var rows: [UserProfileListRow<Route>] = sectionStartRows.map(nextCustomRow)

    for builtInRow in builtInRows {
      rows.append(contentsOf: rowsBeforeAnchor[builtInRow, default: []].map(nextCustomRow))
      rows.append(.builtIn(builtInRow))
      rows.append(contentsOf: rowsAfterAnchor[builtInRow, default: []].map(nextCustomRow))
    }

    rows.append(contentsOf: sectionEndRows.map(nextCustomRow))
    return rows
  }
}

// MARK: - Actions

extension UserProfileView {
  fileprivate func signOut(sessionId: String) async {
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

  fileprivate func getSessionsOnAllDevices() async {
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

// MARK: - Types

private enum UserProfileListRow<Route: Hashable>: Identifiable {
  case builtIn(UserProfileRow)
  case custom(UserProfileCustomRow<Route>, occurrence: Int)

  var id: UserProfileListRowID<Route> {
    switch self {
    case .builtIn(let row):
      .builtIn(row)
    case .custom(let row, let occurrence):
      .custom(route: row.route, occurrence: occurrence)
    }
  }
}

private enum UserProfileListRowID<Route: Hashable>: Hashable {
  case builtIn(UserProfileRow)
  case custom(route: Route, occurrence: Int)
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

#Preview("With custom rows") {
  UserProfileView()
    .userProfileRows([
      UserProfileCustomRow(
        route: "billing",
        title: "Billing",
        icon: .asset(name: "icon-security"),
        placement: .after(.security)
      ),
      UserProfileCustomRow(
        route: "preferences",
        title: "Preferences",
        icon: .asset(name: "icon-switch"),
        placement: .before(.signOut)
      ),
    ])
    .userProfileDestination { route in
      switch route {
      case "billing":
        Text("Billing")
      case "preferences":
        Text("Preferences")
      default:
        EmptyView()
      }
    }
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

#Preview("Embedded in parent NavigationStack") {
  @Previewable @State var navigationPath = NavigationPath()

  UserProfileView(isDismissable: false, navigationPath: $navigationPath)
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
