//
//  SessionTaskCreateOrganizationView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskCreateOrganizationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AuthNavigation.self) private var navigation

  let creationDefaults: OrganizationCreationDefaults?
  var showBackButton = false

  var body: some View {
    OrganizationCreateView(creationDefaults: creationDefaults) { organization in
      try await selectOrganization(id: organization.id)
    }
    .navigationBarBackButtonHidden(!showBackButton)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
  }

  private func selectOrganization(id: String) async throws {
    guard let session = clerk.session else { return }
    try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
    navigation.handleSessionTaskCompletion(session: clerk.session)
  }
}

#Preview("Create Organization") {
  SessionTaskCreateOrganizationView(creationDefaults: nil)
    .clerkPreview()
}

#endif
