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
  @State private var activeMembership: OrganizationMembership?
  @State private var activeOrganization: Organization?
  @State private var isLoadingActiveOrganization = true
  @State private var error: Error?

  private var activeOrganizationId: String? {
    clerk.session?.lastActiveOrganizationId
  }

  private var organization: Organization? {
    activeMembership?.organization ?? activeOrganization
  }

  private var visibility: OrganizationProfileVisibility {
    OrganizationProfileVisibility(
      membership: activeMembership,
      organization: organization,
      organizationSettings: clerk.environment?.organizationSettings
    )
  }

  private var profileRows: [OrganizationProfileRow] {
    var rows: [OrganizationProfileRow] = []

    if visibility.showsMembers {
      rows.append(.members)
    }

    if visibility.showsVerifiedDomains {
      rows.append(.verifiedDomains)
    }

    return rows
  }

  private var actionRows: [OrganizationProfileRow] {
    var rows: [OrganizationProfileRow] = []

    if visibility.showsLeaveOrganization {
      rows.append(.leaveOrganization)
    }

    if visibility.showsDeleteOrganization {
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
    if clerk.user != nil {
      Group {
        if navigationPath == nil {
          NavigationStack(path: $internalPath) {
            profileContent
          }
        } else {
          profileContent
        }
      }
      .tint(theme.colors.primary)
      .presentationBackground(theme.colors.background)
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .task(id: activeOrganizationId) {
        await loadActiveOrganization()
      }
      .task {
        _ = try? await clerk.refreshEnvironment()
      }
      .task {
        _ = try? await clerk.refreshClient()
      }
    }
  }

  private var profileContent: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 0) {
          if let organization {
            OrganizationProfileHeaderView(
              organization: organization,
              showsUpdateProfile: visibility.showsUpdateProfile,
              onUpdateProfile: updateProfile
            )

            VStack(spacing: 48) {
              section(rows: profileRows)
              section(rows: actionRows)
            }
          } else if isLoadingActiveOrganization {
            SpinnerView()
              .frame(width: 32, height: 32)
              .frame(maxWidth: .infinity, minHeight: 220)
          }
        }
      }
      .background(theme.colors.muted)

      SecuredByClerkFooter()
    }
    .animation(.default, value: activeOrganization)
    .animation(.default, value: activeMembership)
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
  private func loadActiveOrganization() async {
    guard let activeOrganizationId else {
      activeMembership = nil
      activeOrganization = nil
      isLoadingActiveOrganization = false
      return
    }

    isLoadingActiveOrganization = true
    defer { isLoadingActiveOrganization = false }

    if let membership = clerk.user?.organizationMemberships?.first(where: { $0.organization.id == activeOrganizationId }) {
      activeMembership = membership
      activeOrganization = membership.organization
      return
    }

    do {
      activeMembership = nil
      activeOrganization = try await clerk.organizations.get(id: activeOrganizationId)
    } catch {
      self.error = error
    }
  }

  private func updateProfile() {}

  private func action(for row: OrganizationProfileRow) async {
    switch row {
    case .members, .verifiedDomains, .leaveOrganization, .deleteOrganization:
      break
    }
  }
}

// MARK: - Types

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
