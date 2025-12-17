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
        // User Avatar
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

        // User Name
        if let firstName = clerk.user?.firstName, let lastName = clerk.user?.lastName {
          Text("\(firstName) \(lastName)")
            .font(.title)
            .bold()
        } else if let firstName = clerk.user?.firstName {
          Text(firstName)
            .font(.title)
            .bold()
        } else if let username = clerk.user?.username {
          Text(username)
            .font(.title)
            .bold()
        } else if let primaryEmailAddress = clerk.user?.primaryEmailAddress {
          Text(primaryEmailAddress.emailAddress)
            .font(.title)
            .bold()
        }

        // Sign Out Button
        Button {
          signOut()
        } label: {
          Text("Sign Out")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding(.horizontal)
      }
      .padding(.vertical, 32)
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

// MARK: - AvatarPlaceholder

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
