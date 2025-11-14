//
//  ContentView.swift
//  WatchExampleApp Watch App
//
//  Created on 2025-01-27.
//

import ClerkKit
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk

  var fullName: String? {
    let name = [clerk.user?.firstName, clerk.user?.lastName]
      .compactMap(\.self)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return name.isEmpty ? nil : name
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        if let user = clerk.user {
          // Display shared auth state synced from the iOS app
          VStack(alignment: .leading, spacing: 8) {
            Text("Signed In")
              .font(.headline)
              .fontWeight(.semibold)

            if let fullName = fullName {
              Text(fullName)
                .font(.caption)
            }

            if let email = user.primaryEmailAddress?.emailAddress {
              Text(email)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()

          Button {
            Task {
              try? await clerk.signOut(sessionId: clerk.session?.id)
            }
          } label: {
            Text("Sign Out")
          }
          .buttonStyle(.borderedProminent)
        } else {
          VStack(spacing: 8) {
            Text("Not Signed In")
              .font(.headline)
              .fontWeight(.semibold)

            Text("Sign in on your iPhone to sync your authentication state to your Apple Watch.")
              .font(.caption2)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding()
        }
      }
      .padding()
    }
  }
}

#Preview("Signed Out") {
  ContentView()
    .environment(
      Clerk.preview { preview in
        preview.isSignedIn = false
      })
}

#Preview("Signed In") {
  ContentView()
    .environment(Clerk.preview())
}
