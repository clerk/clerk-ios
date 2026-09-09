//
//  ProfileView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ProfileView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback

  var body: some View {
    VStack(spacing: 24) {
      if let imageUrl = clerk.user?.imageUrl, let url = URL(string: imageUrl) {
        AsyncImage(
          url: url,
          transaction: Transaction(animation: .default)
        ) { phase in
          if case .success(let image) = phase {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          }
        }
        .frame(width: 100, height: 100)
        .clipShape(.circle)
      }

      Text(clerk.user?.id ?? "No user ID")

      Button("Sign Out") {
        signOut()
      }
      .buttonStyle(.borderedProminent)
    }
  }

  private func signOut() {
    Task {
      do {
        try await clerk.signOut()
      } catch {
        feedback.error = error.localizedDescription
      }
    }
  }
}

#Preview {
  NavigationStack {
    ProfileView()
      .environment(Clerk.preview())
      .environment(CustomFlowFeedback())
  }
}
