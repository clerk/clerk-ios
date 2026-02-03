//
//  SessionTaskView.swift
//  Clerk
//
//  Created by Clerk on 1/28/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SessionTaskView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  var session: Session? {
    // Find the first pending session with tasks (might not be the active session)
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var body: some View {
    if let taskKey = session?.currentTaskKey {
      switch taskKey {
      case .resetPassword:
        SessionTaskResetPasswordView()
      case .setupMfa:
        SetupMfaStartView()
      case .unknown:
        unknownTaskView
      }
    } else {
      unknownTaskView
    }
  }

  var unknownTaskView: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Action Required")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "This account requires additional verification before you can continue. Please contact support for assistance.")
          .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .navigationBarBackButtonHidden()
  }
}

#Preview {
  SessionTaskView()
    .environment(\.clerkTheme, .clerk)
}

#endif
