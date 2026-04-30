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
    OrganizationCreateView(creationDefaults: creationDefaults) {
      navigation.handleSessionTaskCompletion(session: clerk.session)
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
}

#Preview("Create Organization") {
  SessionTaskCreateOrganizationView(creationDefaults: nil)
    .clerkPreview()
}

#endif
