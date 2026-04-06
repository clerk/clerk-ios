//
//  SessionTaskStartView.swift
//

#if os(iOS)

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
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            UserButton(presentationContext: .sessionTaskToolbar)
          }
        }
    case .chooseOrganization:
      SessionTaskChooseOrganizationView()
    case .unknown:
      GetHelpView(context: .sessionTask)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            UserButton(presentationContext: .sessionTaskToolbar)
          }
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
