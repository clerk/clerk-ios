//
//  OrganizationProfileView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A prebuilt organization profile view for the active organization.
///
/// ``OrganizationProfileView`` provides a native interface for viewing and managing
/// the currently active organization. It includes permission-gated organization profile
/// editing, members, invitations, membership requests, verified domains, leave organization,
/// and delete organization flows.
///
/// The view renders content only when a session has an active organization. Rows and actions
/// are shown according to the current user's organization membership permissions and the
/// current environment settings.
///
/// ## Usage
///
/// As a dismissable sheet:
///
/// ```swift
/// struct OrganizationSettingsButton: View {
///   @State private var profileIsPresented = false
///
///   var body: some View {
///     Button("Organization settings") {
///       profileIsPresented = true
///     }
///     .sheet(isPresented: $profileIsPresented) {
///       OrganizationProfileView()
///     }
///   }
/// }
/// ```
///
/// Embedded in a parent `NavigationStack`:
///
/// ```swift
/// struct OrganizationSettingsView: View {
///   @State private var path = NavigationPath()
///
///   var body: some View {
///     NavigationStack(path: $path) {
///       OrganizationProfileView(isDismissable: false, navigationPath: $path)
///     }
///   }
/// }
/// ```
///
/// With custom rows:
///
/// ```swift
/// enum OrganizationRoute: Hashable {
///   case billing
///   case preferences
/// }
///
/// OrganizationProfileView()
///   .organizationProfileRows([
///     .init(
///       route: .billing,
///       title: "Billing",
///       icon: .system(name: "creditcard"),
///       placement: .after(.members)
///     ),
///     .init(
///       route: .preferences,
///       title: "Preferences",
///       icon: .system(name: "gear"),
///       placement: .before(.leaveOrganization)
///     ),
///   ])
///   .organizationProfileDestination { (route: OrganizationRoute) in
///     switch route {
///     case .billing:
///       BillingView()
///     case .preferences:
///       PreferencesView()
///     }
///   }
/// ```
public struct OrganizationProfileView<Route: Hashable, Destination: View>: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let isDismissable: Bool
  private let navigationPath: Binding<NavigationPath>?
  private let customRows: [OrganizationProfileCustomRow<Route>]
  private let customDestination: (@MainActor (Route) -> Destination)?

  @State private var internalPath = NavigationPath()
  @State private var initialPathCount = 0
  @State private var updateProfileIsPresented = false
  @State private var presentedConfirmation: OrganizationProfileActionConfirmation?

  private var organization: Organization? {
    clerk.organization
  }

  private var organizationMembership: OrganizationMembership? {
    clerk.organizationMembership
  }

  private var showsUpdateProfile: Bool {
    organizationMembership?.canManageProfile == true
  }

  private var profileRows: [OrganizationProfileRow] {
    var rows: [OrganizationProfileRow] = []

    if organizationMembership?.canReadMemberships == true || organizationMembership?.canManageMemberships == true {
      rows.append(.members)
    }

    if clerk.environment?.organizationSettings.domains.enabled == true,
       organizationMembership?.canReadDomains == true || organizationMembership?.canManageDomains == true
    {
      rows.append(.verifiedDomains)
    }

    return rows
  }

  private var actionRows: [OrganizationProfileRow] {
    var rows: [OrganizationProfileRow] = []

    if organizationMembership != nil {
      rows.append(.leaveOrganization)
    }

    if clerk.environment?.organizationSettings.actions.adminDelete == true,
       organization?.adminDeleteEnabled == true,
       organizationMembership?.canDeleteOrganization == true
    {
      rows.append(.deleteOrganization)
    }

    return rows
  }

  init(
    isDismissable: Bool,
    navigationPath: Binding<NavigationPath>?,
    customRows: [OrganizationProfileCustomRow<Route>],
    customDestination: (@MainActor (Route) -> Destination)?
  ) {
    self.isDismissable = isDismissable
    self.navigationPath = navigationPath
    self.customRows = customRows
    self.customDestination = customDestination
  }

  /// Creates a new organization profile view.
  ///
  /// - Parameters:
  ///   - isDismissable: Whether the view can be dismissed by the user. When `true`,
  ///     a dismiss button appears in the navigation bar. When `false`, no dismiss
  ///     button is shown.
  ///   - navigationPath: An optional parent navigation path for embedded usage. Pass
  ///     a parent path when the view is hosted inside your own `NavigationStack`.
  public init(
    isDismissable: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil
  ) where Route == Never, Destination == EmptyView {
    self.init(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: [],
      customDestination: nil
    )
  }

  public var body: some View {
    Group {
      if let organization {
        Group {
          if navigationPath == nil {
            NavigationStack(path: $internalPath) {
              profileContent(organization: organization)
                .navigationDestination(for: Route.self) { route in
                  view(for: route)
                    .environment(
                      OrganizationProfileNavigator(
                        push: navigateToCustom,
                        popToRoot: { dismissAction(.popToRoot) }
                      )
                    )
                    .environment(
                      OrganizationProfileBuiltInRouter(
                        push: navigateToBuiltIn,
                        dismissAction: dismissAction
                      )
                    )
                }
            }
          } else {
            profileContent(organization: organization)
          }
        }
        .tint(theme.colors.primary)
        .presentationBackground(theme.colors.background)
        .background(theme.colors.background)
        .onFirstAppear {
          initialPathCount = navigationPath?.wrappedValue.count ?? 0
        }
        .sheet(isPresented: $updateProfileIsPresented) {
          OrganizationProfileUpdateProfileView(organization: organization)
        }
        .sheet(item: $presentedConfirmation) { confirmation in
          OrganizationProfileActionConfirmationView(
            action: confirmation,
            organization: organization
          )
        }
        .task {
          _ = try? await clerk.refreshEnvironment()
        }
        .task {
          _ = try? await clerk.refreshClient()
        }
        .environment(
          OrganizationProfileBuiltInRouter(
            push: navigateToBuiltIn,
            dismissAction: dismissAction
          )
        )
      }
    }
  }

  private func profileContent(organization: Organization) -> some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 0) {
          OrganizationProfileHeaderView(
            organization: organization,
            showsUpdateProfile: showsUpdateProfile,
            onUpdateProfile: {
              updateProfileIsPresented = true
            }
          )

          VStack(spacing: 48) {
            section(rows: renderedRows(builtInRows: profileRows, in: .profile))
            section(rows: renderedRows(builtInRows: actionRows, in: .actions))
          }
        }
      }
      .background(theme.colors.muted)

      SecuredByClerkFooter()
    }
    .animation(.default, value: organization)
    .animation(.default, value: organizationMembership)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Organization", bundle: .module)
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
    .navigationDestination(for: OrganizationProfileBuiltInDestination.self) { destination in
      view(for: destination)
        .environment(
          OrganizationProfileNavigator(
            push: navigateToCustom,
            popToRoot: { dismissAction(.popToRoot) }
          )
        )
        .environment(
          OrganizationProfileBuiltInRouter(
            push: navigateToBuiltIn,
            dismissAction: dismissAction
          )
        )
    }
  }
}

// MARK: - View Modifiers

extension OrganizationProfileView {
  /// Replaces the custom rows rendered on the root organization profile screen.
  public func organizationProfileRows(
    _ rows: [OrganizationProfileCustomRow<Route>]
  ) -> OrganizationProfileView<Route, Destination> {
    OrganizationProfileView<Route, Destination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: rows,
      customDestination: customDestination
    )
  }
}

extension OrganizationProfileView where Destination == EmptyView {
  /// Sets the custom destination builder used by custom organization profile rows.
  ///
  /// This modifier is used when `OrganizationProfileView` manages its own `NavigationStack`
  /// (i.e., no `navigationPath` is provided). When you provide a `navigationPath`,
  /// register your own `.navigationDestination(for:)` on the parent stack instead.
  public func organizationProfileDestination<NewDestination: View>(
    @ViewBuilder _ destination: @escaping @MainActor (Route) -> NewDestination
  ) -> OrganizationProfileView<Route, NewDestination> {
    OrganizationProfileView<Route, NewDestination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: customRows,
      customDestination: destination
    )
  }
}

extension OrganizationProfileView where Route == Never, Destination == EmptyView {
  /// Sets the custom rows rendered on the root organization profile screen.
  public func organizationProfileRows<NewRoute: Hashable>(
    _ rows: [OrganizationProfileCustomRow<NewRoute>]
  ) -> OrganizationProfileView<NewRoute, EmptyView> {
    OrganizationProfileView<NewRoute, EmptyView>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: rows,
      customDestination: nil
    )
  }

  /// Sets the custom destination builder used by custom organization profile rows.
  ///
  /// This modifier is used when `OrganizationProfileView` manages its own `NavigationStack`
  /// (i.e., no `navigationPath` is provided). When you provide a `navigationPath`,
  /// register your own `.navigationDestination(for:)` on the parent stack instead.
  public func organizationProfileDestination<NewRoute: Hashable, NewDestination: View>(
    for _: NewRoute.Type = NewRoute.self,
    @ViewBuilder _ destination: @escaping @MainActor (NewRoute) -> NewDestination
  ) -> OrganizationProfileView<NewRoute, NewDestination> {
    OrganizationProfileView<NewRoute, NewDestination>(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customRows: [],
      customDestination: destination
    )
  }
}

// MARK: - Subviews

extension OrganizationProfileView {
  @ViewBuilder
  private func section(rows: [OrganizationProfileListRow<Route>]) -> some View {
    if !rows.isEmpty {
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
  }

  @ViewBuilder
  private func rowView(_ listRow: OrganizationProfileListRow<Route>) -> some View {
    switch listRow {
    case .builtIn(let builtInRow):
      builtInRowView(builtInRow)
    case .custom(let customRow, _):
      row(icon: customRow.icon, text: customRow.title, bundle: nil) {
        navigateToCustom(customRow.route)
      }
    }
  }

  private func builtInRowView(_ rowType: OrganizationProfileRow) -> some View {
    row(icon: rowType.icon, text: rowType.title) {
      await action(for: rowType)
    }
  }

  private func row(
    icon: OrganizationProfileRowIcon,
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
}

// MARK: - Ordering

extension OrganizationProfileView {
  private func renderedRows(
    builtInRows: [OrganizationProfileRow],
    in section: OrganizationProfileSection
  ) -> [OrganizationProfileListRow<Route>] {
    let sectionCustomRows = customRows.filter { $0.placement.section == section }

    let sectionStartRows = sectionCustomRows.filter { $0.placement.isSectionStart }
    let sectionEndRows = sectionCustomRows.filter { $0.placement.isSectionEnd }

    let rowsBeforeAnchor = sectionCustomRows.reduce(into: [OrganizationProfileRow: [OrganizationProfileCustomRow<Route>]]()) { result, customRow in
      guard case .before(let anchor) = customRow.placement else { return }
      result[anchor, default: []].append(customRow)
    }

    let rowsAfterAnchor = sectionCustomRows.reduce(into: [OrganizationProfileRow: [OrganizationProfileCustomRow<Route>]]()) { result, customRow in
      guard case .after(let anchor) = customRow.placement else { return }
      result[anchor, default: []].append(customRow)
    }

    var routeOccurrences = [AnyHashable: Int]()

    func nextCustomRow(_ customRow: OrganizationProfileCustomRow<Route>) -> OrganizationProfileListRow<Route> {
      let key = AnyHashable(customRow.route)
      let occurrence = routeOccurrences[key, default: 0]
      routeOccurrences[key] = occurrence + 1
      return .custom(customRow, occurrence: occurrence)
    }

    var rows: [OrganizationProfileListRow<Route>] = sectionStartRows.map(nextCustomRow)

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

extension OrganizationProfileView {
  private func action(for row: OrganizationProfileRow) async {
    switch row {
    case .members:
      navigateToBuiltIn(.members)
    case .verifiedDomains:
      navigateToBuiltIn(.verifiedDomains)
    case .leaveOrganization:
      presentedConfirmation = .leave
    case .deleteOrganization:
      presentedConfirmation = .delete
    }
  }

  private func navigateToBuiltIn(_ destination: OrganizationProfileBuiltInDestination) {
    pushDestination(destination)
  }

  private func navigateToCustom(_ route: Route) {
    pushDestination(route)
  }

  private func pushDestination(_ destination: any Hashable) {
    if let navigationPath {
      navigationPath.wrappedValue.append(destination)
    } else {
      internalPath.append(destination)
    }
  }

  private func dismissAction(_ action: OrganizationProfileDismissAction) {
    let extraRemoval = action == .exitOrganizationProfile ? 1 : 0

    if let navigationPath {
      let currentCount = navigationPath.wrappedValue.count
      let entriesToRemove = min(max(currentCount - initialPathCount + extraRemoval, 0), currentCount)
      navigationPath.wrappedValue.removeLast(entriesToRemove)
    } else {
      internalPath = NavigationPath()
      if action == .exitOrganizationProfile {
        dismiss()
      }
    }
  }

  @ViewBuilder
  private func view(for destination: OrganizationProfileBuiltInDestination) -> some View {
    switch destination {
    case .members:
      OrganizationMembersView()
    case .verifiedDomains:
      OrganizationVerifiedDomainsView()
    }
  }

  @ViewBuilder
  private func view(for route: Route) -> some View {
    if let customDestination {
      customDestination(route)
    } else {
      EmptyView()
        .onAppear {
          ClerkLogger.error("No destination registered for custom organization route \(route). Use .organizationProfileDestination to provide one.")
        }
    }
  }
}

private enum OrganizationProfileListRow<Route: Hashable>: Identifiable {
  case builtIn(OrganizationProfileRow)
  case custom(OrganizationProfileCustomRow<Route>, occurrence: Int)

  var id: OrganizationProfileListRowID<Route> {
    switch self {
    case .builtIn(let row):
      .builtIn(row)
    case .custom(let row, let occurrence):
      .custom(route: row.route, occurrence: occurrence)
    }
  }
}

private enum OrganizationProfileListRowID<Route: Hashable>: Hashable {
  case builtIn(OrganizationProfileRow)
  case custom(route: Route, occurrence: Int)
}

#Preview("Organization Profile") {
  OrganizationProfileView()
    .environment(Clerk.preview { preview in
      var membership = OrganizationMembership.mockWithUserData
      membership.permissions = [
        OrganizationSystemPermission.manageProfile.rawValue,
        OrganizationSystemPermission.readMemberships.rawValue,
        OrganizationSystemPermission.readDomains.rawValue,
        OrganizationSystemPermission.deleteProfile.rawValue,
      ]

      var user = User.mock
      user.organizationMemberships = [membership]

      var session = Session.mock
      session.lastActiveOrganizationId = membership.organization.id
      session.user = user

      var client = Client.mock
      client.sessions = [session]
      client.lastActiveSessionId = session.id

      var environment = Clerk.Environment.mock
      environment.organizationSettings.domains.enabled = true
      preview.client = client
      preview.environment = environment
    })
}

#endif
