//
//  OrganizationMembersView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationMembersView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var selectedTab: OrganizationMembersTab = .members
  @State private var dataSource = OrganizationMembersDataSource()
  @State private var inviteMembersIsPresented = false

  private var organization: Organization? {
    clerk.organization
  }

  private var organizationMembership: OrganizationMembership? {
    clerk.organizationMembership
  }

  private var canReadMemberships: Bool {
    organizationMembership?.canReadMemberships == true
  }

  private var canManageMemberships: Bool {
    organizationMembership?.canManageMemberships == true
  }

  private var canManageMembershipRequests: Bool {
    canManageMemberships && clerk.environment?.organizationSettings.domains.enabled == true
  }

  private var availableTabs: [OrganizationMembersTab] {
    var tabs: [OrganizationMembersTab] = []
    if canReadMemberships {
      tabs.append(.members)
    }
    if canManageMemberships {
      tabs.append(.invitations)
    }
    if canManageMembershipRequests {
      tabs.append(.requests)
    }
    return tabs
  }

  private var canInviteMembers: Bool {
    guard let organization else { return false }
    if organization.maxAllowedMemberships == 0 {
      return true
    }

    let membersCount = organization.membersCount ?? 0
    let pendingInvitationsCount = organization.pendingInvitationsCount ?? 0
    return membersCount + pendingInvitationsCount < organization.maxAllowedMemberships
  }

  var body: some View {
    @Bindable var dataSource = dataSource

    VStack(spacing: 0) {
      if availableTabs.count > 1 {
        tabsPicker
      }

      membersContent
    }
    .background(theme.colors.muted)
    .securedByClerkFooter()
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Members", bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
      }

      if canManageMemberships {
        ToolbarItem(placement: .primaryAction) {
          Button {
            inviteMembersIsPresented = true
          } label: {
            Text("Invite", bundle: .module)
          }
          .disabled(!canInviteMembers)
        }
      }
    }
    .sheet(isPresented: $inviteMembersIsPresented) {
      NavigationStack {
        OrganizationInviteMembersView { completion in
          if completion == .sentInvitations, let organization {
            await dataSource.loadInvitations(organization: organization)
          }
          inviteMembersIsPresented = false
        }
      }
    }
    .clerkErrorPresenting($dataSource.error)
    .task(id: organization?.id) {
      await loadInitialData()
    }
    .onChange(of: availableTabs) {
      normalizeSelectedTab()
    }
  }
}

// MARK: - Subviews

extension OrganizationMembersView {
  private var tabsPicker: some View {
    Picker("", selection: $selectedTab) {
      ForEach(availableTabs) { tab in
        Text(tab.title, bundle: .module)
          .tag(tab)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, selectedTab == .members ? 0 : 12)
  }

  @ViewBuilder
  private var membersContent: some View {
    if availableTabs.contains(selectedTab) {
      switch selectedTab {
      case .members:
        OrganizationMembersTabView(dataSource: dataSource)
      case .invitations:
        OrganizationInvitationsTabView(dataSource: dataSource)
      case .requests:
        OrganizationMembershipRequestsTabView(dataSource: dataSource)
      }
    }
  }
}

// MARK: - Actions

extension OrganizationMembersView {
  @MainActor
  private func loadInitialData() async {
    normalizeSelectedTab()

    await dataSource.loadInitial(
      organization: organization,
      includeMembers: canReadMemberships,
      includeInvitations: canManageMemberships,
      includeMembershipRequests: canManageMembershipRequests
    )
  }

  private func normalizeSelectedTab() {
    if let firstAvailableTab = availableTabs.first, !availableTabs.contains(selectedTab) {
      selectedTab = firstAvailableTab
    }
  }
}

// MARK: - Types

private enum OrganizationMembersTab: Hashable, Identifiable {
  case members
  case invitations
  case requests

  var id: Self {
    self
  }

  var title: LocalizedStringKey {
    switch self {
    case .members:
      "Members"
    case .invitations:
      "Invitations"
    case .requests:
      "Requests"
    }
  }
}

#Preview("Organization Members") {
  NavigationStack {
    OrganizationMembersView()
      .environment(Clerk.preview { preview in
        let organization = Organization.mock
        var membership = OrganizationMembership.mockWithUserData
        membership.organization = organization
        membership.permissions = [
          OrganizationSystemPermission.readMemberships.rawValue,
          OrganizationSystemPermission.manageMemberships.rawValue,
        ]

        var user = User.mock
        user.organizationMemberships = [membership]

        var session = Session.mock
        session.lastActiveOrganizationId = organization.id
        session.user = user

        var client = Client.mock
        client.sessions = [session]
        client.lastActiveSessionId = session.id

        preview.client = client
        var environment = Clerk.Environment.mock
        environment.organizationSettings.domains.enabled = true
        preview.environment = environment
      })
  }
}

#endif
