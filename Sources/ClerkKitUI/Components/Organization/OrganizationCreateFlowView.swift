//
//  OrganizationCreateFlowView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationCreateFlowView: View {
  @Environment(\.dismiss) private var dismiss

  private let creationDefaults: OrganizationCreationDefaults?
  private let skipInvitationScreen: Bool
  private let onComplete: (() -> Void)?

  @State private var inviteMembersIsPresented = false

  init(
    creationDefaults: OrganizationCreationDefaults?,
    skipInvitationScreen: Bool = false,
    onComplete: (() -> Void)? = nil
  ) {
    self.creationDefaults = creationDefaults
    self.skipInvitationScreen = skipInvitationScreen
    self.onComplete = onComplete
  }

  var body: some View {
    OrganizationProfileFormView(creationDefaults: creationDefaults) { organization in
      if shouldShowPostCreateInviteStep(for: organization) {
        inviteMembersIsPresented = true
      } else {
        completeFlow()
      }
    }
    .navigationDestination(isPresented: $inviteMembersIsPresented) {
      OrganizationInviteMembersView(
        cancellationTitle: "Skip",
        cancellationPlacement: .confirmationAction
      ) { _ in
        completeFlow()
      }
      .navigationBarBackButtonHidden(true)
    }
  }

  private func completeFlow() {
    if let onComplete {
      onComplete()
    } else {
      dismiss()
    }
  }

  private func shouldShowPostCreateInviteStep(for organization: Organization) -> Bool {
    !skipInvitationScreen && organization.maxAllowedMemberships != 1
  }
}

#Preview("Create Organization Flow") {
  NavigationStack {
    OrganizationCreateFlowView(creationDefaults: nil)
      .clerkPreview()
  }
}

#endif
