//
//  OrganizationProfileView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A prebuilt organization profile root view.
public struct OrganizationProfileView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private let isDismissable: Bool
  private let navigationPath: Binding<NavigationPath>?

  @State private var internalPath = NavigationPath()
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

  /// Creates a new organization profile view.
  ///
  /// - Parameters:
  ///   - isDismissable: Whether the view can be dismissed by the user.
  ///   - navigationPath: An optional parent navigation path for embedded usage.
  public init(
    isDismissable: Bool = true,
    navigationPath: Binding<NavigationPath>? = nil
  ) {
    self.isDismissable = isDismissable
    self.navigationPath = navigationPath
  }

  public var body: some View {
    if let organization {
      Group {
        if navigationPath == nil {
          NavigationStack(path: $internalPath) {
            profileContent(organization: organization)
          }
        } else {
          profileContent(organization: organization)
        }
      }
      .tint(theme.colors.primary)
      .presentationBackground(theme.colors.background)
      .background(theme.colors.background)
      .sheet(isPresented: $updateProfileIsPresented) {
        OrganizationProfileUpdateProfileView(organization: organization)
      }
      .task {
        _ = try? await clerk.refreshEnvironment()
      }
      .task {
        _ = try? await clerk.refreshClient()
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
    .navigationDestination(for: OrganizationProfileDestination.self) { destination in
      view(for: destination)
    }
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

  private func navigateToBuiltIn(_ destination: OrganizationProfileDestination) {
    if let navigationPath {
      navigationPath.wrappedValue.append(destination)
    } else {
      internalPath.append(destination)
    }
  }

  @ViewBuilder
  private func view(for destination: OrganizationProfileDestination) -> some View {
    switch destination {
    case .members:
      OrganizationMembersView()
    case .verifiedDomains:
      OrganizationVerifiedDomainsView()
    }
  }
}

// MARK: - Types

private enum OrganizationProfileDestination: Hashable {
  case members
  case verifiedDomains
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
