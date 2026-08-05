//
//  SessionTaskStartView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SessionTaskStartView: View {
  let task: Session.Task
  let token: AuthFlowPresentationToken

  @ViewBuilder
  private var viewForTask: some View {
    switch task {
    case .setupMfa:
      SessionTaskMfaSetupView(token: token)
    case .resetPassword:
      SignInSetNewPasswordView(mode: .sessionTask, token: token)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .preGlassSolidNavBar()
      .toolbar {
        UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
      }
    case .chooseOrganization:
      SessionTaskChooseOrganizationView(token: token)
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

#endif
