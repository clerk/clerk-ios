//
//  ProfileView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct ProfileView: View {
  @Environment(Clerk.self) private var clerk

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
        try await clerk.auth.signOut()
      } catch {
        print("Sign out error: \(error.localizedDescription)")
      }
    }
  }
}

#Preview {
  NavigationStack {
    ProfileView()
      .environment(Clerk.preview())
  }
}
