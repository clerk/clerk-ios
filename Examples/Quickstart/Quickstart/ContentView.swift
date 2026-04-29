//
//  ContentView.swift
//  Quickstart
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @State private var authViewIsPresented = false

  var body: some View {
    VStack(spacing: 16) {
      UserButton(signedOutContent: {
        Button("Sign in") {
          authViewIsPresented = true
        }
      })

      OrganizationSwitcher()
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
