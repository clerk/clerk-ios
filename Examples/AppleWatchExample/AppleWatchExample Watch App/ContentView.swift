//
//  ContentView.swift
//  AppleWatchExample Watch App
//
//  Created by Mike Pitre on 7/30/25.
//

import ClerkKit
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        if let user = clerk.user {
          // Display shared auth state from the iOS app
          VStack(alignment: .leading, spacing: 6) {
            Text("Signed In")
              .font(.headline)

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
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        } else {
          VStack(spacing: 8) {
            Text("Not Signed In")
              .font(.headline)

            Text("Sign in on your iPhone to access your account here.")
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




