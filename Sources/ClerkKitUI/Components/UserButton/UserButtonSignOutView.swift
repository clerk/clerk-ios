//
//  UserButtonSignOutView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A simplified user sheet shown during session tasks, displaying the user preview and a sign out option.
struct UserButtonSignOutView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  @State private var error: Error?

  var body: some View {
    VStack(spacing: 0) {
      if let user = clerk.user {
        UserPreviewView(user: user)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 16)
          .padding(.horizontal, 24)
          .overlay(alignment: .bottom) {
            Rectangle()
              .frame(height: 1)
              .foregroundStyle(theme.colors.border)
          }
      }

      AsyncButton {
        await signOut()
      } label: { isRunning in
        UserProfileRowView(icon: "icon-sign-out", text: "Sign out")
          .overlayProgressView(isActive: isRunning)
      }
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
      .buttonStyle(.pressedBackground)
      .simultaneousGesture(TapGesture())
    }
    .padding(.top, 16)
    .preGlassDetentSheetBackground()
    .clerkErrorPresenting($error)
  }

  private func signOut() async {
    guard let sessionId = clerk.session?.id else { return }
    do {
      try await clerk.auth.signOut(sessionId: sessionId)
      dismiss()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to sign out", error: error)
    }
  }
}

#Preview {
  UserButtonSignOutView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
