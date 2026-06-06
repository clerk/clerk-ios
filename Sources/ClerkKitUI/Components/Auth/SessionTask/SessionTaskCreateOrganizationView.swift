//
//  SessionTaskCreateOrganizationView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SessionTaskCreateOrganizationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AuthNavigation.self) private var navigation

  let creationDefaults: OrganizationCreationDefaults?
  var showBackButton = false

  var body: some View {
    OrganizationCreateFlowView(creationDefaults: creationDefaults, skipInvitationScreen: true) {
      navigation.handleSessionTaskCompletion(session: clerk.session)
    }
    .navigationBarBackButtonHidden(!showBackButton)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .preGlassSolidNavBar()
    .toolbar {
      UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
    }
    #if os(macOS)
    .macOSBackButton(hidden: !showBackButton)
    #endif
  }
}

#Preview("Create Organization") {
  SessionTaskCreateOrganizationView(creationDefaults: nil)
    .clerkPreview()
}

#endif
