//
//  SessionTaskStartView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SessionTaskStartView: View {
  let task: Session.Task

  @ViewBuilder
  private var viewForTask: some View {
    switch task {
    case .setupMfa:
      SessionTaskMfaSetupView()
    case .resetPassword:
      SignInSetNewPasswordView(mode: .sessionTask)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .preGlassSolidNavBar()
        .toolbar {
          UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
        }
    case .chooseOrganization:
      SessionTaskChooseOrganizationView()
    case .unknown:
      GetHelpView(context: .sessionTask(.generic))
        .navigationBarBackButtonHidden()
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .preGlassSolidNavBar()
        .toolbar {
          UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
        }
    }
  }

  var body: some View {
    viewForTask
  }
}

#Preview("Setup MFA") {
  SessionTaskStartView(task: .setupMfa)
    .clerkPreview()
}

#Preview("Reset Password") {
  SessionTaskStartView(task: .resetPassword)
    .clerkPreview()
}

#Preview("Choose Organization") {
  SessionTaskStartView(task: .chooseOrganization)
    .clerkPreview()
}

#Preview("Unknown Task") {
  SessionTaskStartView(task: .unknown("new-task"))
    .clerkPreview()
}

#endif
