//
//  SessionTaskMfaTotpConfirmationView.swift
//

#if os(iOS)

import SwiftUI

struct SessionTaskMfaTotpConfirmationView: View {
  @Environment(\.clerkTheme) private var theme

  let onDone: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        SessionTaskHeaderSection(
          title: "Add authenticator application",
          subtitle: "Two-step verification is now enabled. When signing in, you will need to enter a verification code from this authenticator as an additional step."
        )
        .padding(.bottom, 32)

        Button {
          onDone()
        } label: {
          ContinueButtonLabelView()
        }
        .buttonStyle(.primary())
        .padding(.bottom, 32)

        SecuredByClerkView()
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
  }
}

#endif
