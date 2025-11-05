//
//  ContentView.swift
//  AppleWatchExample
//
//  Created by Mike Pitre on 7/30/25.
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @State private var authViewIsPresented = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        if clerk.user != nil {
          VStack(spacing: 12) {
            UserButton()
              .frame(width: 36, height: 36)

            Text("Signed in on iPhone")
              .font(.caption)
              .foregroundColor(.secondary)

            Text("Your authentication state is shared with your Apple Watch")
              .font(.caption2)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
        } else {
          VStack(spacing: 12) {
            Text("Sign in to get started")
              .font(.headline)

            Button("Sign in") {
              authViewIsPresented = true
            }
            .buttonStyle(.borderedProminent)
          }
        }
      }
      .navigationTitle("Clerk Example")
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView()
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
