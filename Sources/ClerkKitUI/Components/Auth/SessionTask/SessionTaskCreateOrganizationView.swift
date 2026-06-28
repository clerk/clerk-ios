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
  let showBackButton: Bool

  init(
    creationDefaults: OrganizationCreationDefaults? = nil,
    showBackButton: Bool = false
  ) {
    self.creationDefaults = creationDefaults
    self.showBackButton = showBackButton
  }

  var body: some View {
    OrganizationCreateFlowView(
      creationDefaults: creationDefaults,
      skipInvitationScreen: true,
      createPresentation: .sessionTask
    ) {
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
  SessionTaskCreateOrganizationView()
    .clerkPreview()
}

#endif
