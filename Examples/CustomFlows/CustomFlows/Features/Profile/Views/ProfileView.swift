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
    ScrollView {
      VStack(spacing: 24) {
        if let imageUrl = clerk.user?.imageUrl, let url = URL(string: imageUrl) {
          AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
            default:
              AvatarPlaceholder()
            }
          }
          .frame(width: 100, height: 100)
          .clipShape(.circle)
        } else {
          AvatarPlaceholder()
            .frame(width: 100, height: 100)
        }

        Text(clerk.user?.id ?? "No user ID")

        Button("Sign Out") {
          signOut()
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
      }
    }
    .navigationTitle("Profile")
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

private struct AvatarPlaceholder: View {
  var body: some View {
    ZStack {
      Color.gray.opacity(0.3)
      Image(systemName: "person.fill")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  NavigationStack {
    ProfileView()
      .environment(Clerk.preview())
  }
}
