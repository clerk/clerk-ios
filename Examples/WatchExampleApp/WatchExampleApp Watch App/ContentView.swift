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

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        if let user = clerk.user {
          // Display shared auth state synced from the iOS app
          VStack(alignment: .leading, spacing: 8) {
            Text("Signed In")
              .font(.headline)
              .fontWeight(.semibold)

            if let firstName = user.firstName {
              Text("First: \(firstName)")
                .font(.caption)
            }

            if let lastName = user.lastName {
              Text("Last: \(lastName)")
                .font(.caption)
            }

            if let email = user.primaryEmailAddress?.emailAddress {
              Text(email)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Text("Token synced via Watch Connectivity")
              .font(.caption2)
              .foregroundColor(.secondary)
              .padding(.top, 4)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        } else {
          VStack(spacing: 8) {
            Text("Not Signed In")
              .font(.headline)
              .fontWeight(.semibold)

            Text("Sign in on your iPhone to sync authentication state to your Apple Watch.")
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
    .environment(Clerk.preview { preview in
      preview.isSignedIn = false
    })
}

#Preview("Signed In") {
  ContentView()
    .environment(Clerk.preview())
}

