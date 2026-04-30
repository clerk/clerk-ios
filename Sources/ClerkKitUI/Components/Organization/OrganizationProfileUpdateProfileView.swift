//
//  OrganizationProfileUpdateProfileView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationProfileUpdateProfileView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let organization: Organization

  init(organization: Organization) {
    self.organization = organization
  }

  var body: some View {
    NavigationStack {
      OrganizationCreateView(
        organization: organization
      ) {
        dismiss()
      }
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }

        ToolbarItem(placement: .principal) {
          Text("Update profile", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
  }
}

#Preview {
  OrganizationProfileUpdateProfileView(organization: .mock)
    .environment(Clerk.preview { preview in
      var membership = OrganizationMembership.mockWithUserData
      membership.permissions = [
        OrganizationSystemPermission.manageProfile.rawValue,
      ]

      var user = User.mock
      user.organizationMemberships = [membership]

      var session = Session.mock
      session.lastActiveOrganizationId = membership.organization.id
      session.user = user

      var client = Client.mock
      client.sessions = [session]
      client.lastActiveSessionId = session.id

      preview.client = client
      preview.environment = .mock
    })
}

#endif
