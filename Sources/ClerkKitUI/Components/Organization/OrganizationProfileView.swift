//
//  OrganizationProfileView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A prebuilt organization profile root view.
public struct OrganizationProfileView<Route: Hashable, Destination: View>: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private let isDismissable: Bool
  private let navigationPath: Binding<NavigationPath>?
  private let customDestination: (@MainActor (Route) -> Destination)?

  @State private var internalPath = NavigationPath()
  @State private var sheetNavigation = OrganizationSheetNavigation()
  @State private var initialPathCount = 0
  @State private var updateProfileIsPresented = false

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
    customDestination: (@MainActor (Route) -> Destination)?
  ) {
    self.isDismissable = isDismissable
    self.navigationPath = navigationPath
    self.customDestination = customDestination
  }

  /// Creates a new organization profile view.
  ///
  /// - Parameters:
  ///   - isDismissable: Whether the view can be dismissed by the user.
  ///   - navigationPath: An optional parent navigation path for embedded usage.
  public init(
    isDismissable: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil
  ) where Route == Never, Destination == EmptyView {
    self.init(
      isDismissable: isDismissable,
      navigationPath: navigationPath,
      customDestination: nil
    )
  }

  public var body: some View {
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
                  .environment(sheetNavigation)
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
      .environment(sheetNavigation)
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
            section(rows: profileRows)
            section(rows: actionRows)
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
        .environment(sheetNavigation)
    }
  }
}

// MARK: - View Modifiers

extension OrganizationProfileView {
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
      customDestination: destination
    )
  }
}

extension OrganizationProfileView where Route == Never, Destination == EmptyView {
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
      customDestination: destination
    )
  }
}

// MARK: - Subviews

extension OrganizationProfileView {
  @ViewBuilder
  private func section(rows: [OrganizationProfileRow]) -> some View {
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

  private func rowView(_ row: OrganizationProfileRow) -> some View {
    AsyncButton {
      await action(for: row)
    } label: { isRunning in
      UserProfileRowView(icon: row.icon, text: row.title)
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

extension OrganizationProfileView {
  private func action(for row: OrganizationProfileRow) async {
    switch row {
    case .members:
      navigateToBuiltIn(.members)
    case .verifiedDomains:
      navigateToBuiltIn(.verifiedDomains)
    case .leaveOrganization, .deleteOrganization:
      break
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

private enum OrganizationProfileRow: Hashable, Identifiable {
  case members
  case verifiedDomains
  case leaveOrganization
  case deleteOrganization

  var id: Self {
    self
  }

  var icon: UserProfileRowIcon {
    switch self {
    case .members:
      .system(name: "person.2.fill")
    case .verifiedDomains:
      .asset(name: "icon-security")
    case .leaveOrganization, .deleteOrganization:
      .asset(name: "icon-sign-out")
    }
  }

  var title: LocalizedStringKey {
    switch self {
    case .members:
      "Members"
    case .verifiedDomains:
      "Verified domains"
    case .leaveOrganization:
      "Leave organization"
    case .deleteOrganization:
      "Delete organization"
    }
  }
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
