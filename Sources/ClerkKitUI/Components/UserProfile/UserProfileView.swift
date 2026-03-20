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
/// With custom items:
///
/// ```swift
/// enum ProfileRoute: Hashable {
///   case billing
///   case preferences
/// }
///
/// UserProfileView()
///   .userProfileItems([
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
  private let customItems: [UserProfileCustomItem<Route>]
  private let customDestination: (@MainActor (Route) -> Destination)?

  @State private var updateProfileIsPresented = false
  @State private var accountSwitcherHeight: CGFloat = 400
  @State private var initialPathCount: Int
  @State private var internalPath = NavigationPath()
  @State private var navigation = UserProfileSheetNavigation()
  @State private var codeLimiter = CodeLimiter()
  @State private var error: Error?

  init(
    isDismissable: Bool,
    navigationPath: Binding<NavigationPath>?,
    customItems: [UserProfileCustomItem<Route>],
    customDestination: (@MainActor (Route) -> Destination)?
  ) {
    self.isDismissable = isDismissable
    self.navigationPath = navigationPath
    self.customItems = customItems
    self.customDestination = customDestination
    _initialPathCount = State(initialValue: navigationPath?.wrappedValue.count ?? 0)
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
      customItems: [],
      customDestination: nil
    )
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
      .environment(
        UserProfileBuiltInRouter(
          push: { row in
            navigate(to: .builtIn(row))
          },
          dismissAction: dismissAction
        )
      )
    }
  }

  private func navigate(to destination: UserProfileNavigationDestination<Route>) {
    if let navigationPath {
      navigationPath.wrappedValue.append(destination)
    } else {
      internalPath.append(destination)
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
    .navigationDestination(for: UserProfileNavigationDestination<Route>.self) { destination in
      view(for: destination)
        .environment(navigation)
        .environment(codeLimiter)
        .environment(
          UserProfileNavigator(
            push: { route in
              navigate(to: .custom(route))
            },
            popToRoot: {
              dismissAction(.popToRoot)
            }
          )
        )
        .environment(
          UserProfileBuiltInRouter(
            push: { row in
              navigate(to: .builtIn(row))
            },
            dismissAction: dismissAction
          )
        )
    }
  }
}

// MARK: - View Modifiers

extension UserProfileView {
  /// Replaces the custom items rendered on the root user profile screen.
  public func userProfileItems(
    _ items: [UserProfileCustomItem<Route>]
  ) -> UserProfileView<Route, Destination> {
    UserProfileView<Route, Destination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customItems: items,
      customDestination: customDestination
    )
  }
}

extension UserProfileView where Destination == EmptyView {
  /// Sets the custom destination builder used by custom user profile items.
  public func userProfileDestination<NewDestination: View>(
    @ViewBuilder _ destination: @escaping @MainActor (Route) -> NewDestination
  ) -> UserProfileView<Route, NewDestination> {
    UserProfileView<Route, NewDestination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customItems: customItems,
      customDestination: destination
    )
  }
}

extension UserProfileView where Route == Never, Destination == EmptyView {
  /// Sets the custom items rendered on the root user profile screen.
  public func userProfileItems<NewRoute: Hashable>(
    _ items: [UserProfileCustomItem<NewRoute>]
  ) -> UserProfileView<NewRoute, EmptyView> {
    UserProfileView<NewRoute, EmptyView>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customItems: items,
      customDestination: nil
    )
  }

  /// Sets the custom destination builder used by custom user profile items.
  public func userProfileDestination<NewRoute: Hashable, NewDestination: View>(
    for _: NewRoute.Type = NewRoute.self,
    @ViewBuilder _ destination: @escaping @MainActor (NewRoute) -> NewDestination
  ) -> UserProfileView<NewRoute, NewDestination> {
    UserProfileView<NewRoute, NewDestination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customItems: [],
      customDestination: destination
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
    case .custom(let customItem):
      row(icon: customItem.icon, text: customItem.title, bundle: customItem.bundle) {
        navigate(to: .custom(customItem.route))
      }
    }
  }

  fileprivate func builtInRowView(_ rowType: UserProfileRow) -> some View {
    row(icon: rowType.icon, text: rowType.title) {
      switch rowType {
      case .manageAccount, .security:
        navigate(to: .builtIn(rowType))
      case .switchAccount:
        navigation.accountSwitcherIsPresented = true
      case .addAccount:
        navigation.authViewIsPresented = true
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
  fileprivate func view(for destination: UserProfileNavigationDestination<Route>) -> some View {
    switch destination {
    case .builtIn(.manageAccount):
      UserProfileDetailView()
    case .builtIn(.security):
      UserProfileSecurityView()
    case .builtIn:
      EmptyView()
    case .custom(let route):
      if let customDestination {
        customDestination(route)
      } else {
        EmptyView()
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
    let sectionCustomItems = customItems.filter { $0.placement.section == section }

    let sectionStartRows = sectionCustomItems.filter { $0.placement.isSectionStart }
    let sectionEndRows = sectionCustomItems.filter { $0.placement.isSectionEnd }

    let rowsBeforeAnchor = sectionCustomItems.reduce(into: [UserProfileRow: [UserProfileCustomItem<Route>]]()) { result, customItem in
      guard case .before(let anchor) = customItem.placement else { return }
      result[anchor, default: []].append(customItem)
    }

    let rowsAfterAnchor = sectionCustomItems.reduce(into: [UserProfileRow: [UserProfileCustomItem<Route>]]()) { result, customItem in
      guard case .after(let anchor) = customItem.placement else { return }
      result[anchor, default: []].append(customItem)
    }

    var rows = sectionStartRows.map(UserProfileListRow.custom)

    for builtInRow in builtInRows {
      rows.append(contentsOf: rowsBeforeAnchor[builtInRow, default: []].map(UserProfileListRow.custom))
      rows.append(.builtIn(builtInRow))
      rows.append(contentsOf: rowsAfterAnchor[builtInRow, default: []].map(UserProfileListRow.custom))
    }

    rows.append(contentsOf: sectionEndRows.map(UserProfileListRow.custom))
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
  case custom(UserProfileCustomItem<Route>)

  var id: UserProfileListRowID<Route> {
    switch self {
    case .builtIn(let row):
      .builtIn(row)
    case .custom(let row):
      .custom(row.route)
    }
  }
}

private enum UserProfileListRowID<Route: Hashable>: Hashable {
  case builtIn(UserProfileRow)
  case custom(Route)
}

extension UserProfileCustomItemPlacement {
  fileprivate var section: UserProfileSection {
    switch self {
    case .sectionStart(let section):
      section
    case .sectionEnd(let section):
      section
    case .before(let row):
      row.section
    case .after(let row):
      row.section
    }
  }

  fileprivate var isSectionStart: Bool {
    switch self {
    case .sectionStart:
      true
    default:
      false
    }
  }

  fileprivate var isSectionEnd: Bool {
    switch self {
    case .sectionEnd:
      true
    default:
      false
    }
  }
}

extension UserProfileRow {
  fileprivate var section: UserProfileSection {
    switch self {
    case .manageAccount, .security:
      .profile
    case .switchAccount, .addAccount, .signOut:
      .account
    }
  }

  fileprivate var icon: String {
    switch self {
    case .manageAccount:
      "icon-profile"
    case .security:
      "icon-security"
    case .switchAccount:
      "icon-switch"
    case .addAccount:
      "icon-plus"
    case .signOut:
      "icon-sign-out"
    }
  }

  fileprivate var title: LocalizedStringKey {
    switch self {
    case .manageAccount:
      "Manage account"
    case .security:
      "Security"
    case .switchAccount:
      "Switch account"
    case .addAccount:
      "Add account"
    case .signOut:
      "Sign out"
    }
  }
}

// MARK: - Header

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

#Preview("With custom items") {
  UserProfileView()
    .userProfileItems([
      UserProfileCustomItem(
        route: "billing",
        title: "Billing",
        icon: .asset(name: "icon-security"),
        placement: .after(.security)
      ),
      UserProfileCustomItem(
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
