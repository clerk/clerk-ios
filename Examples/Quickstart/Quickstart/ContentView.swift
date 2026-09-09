//
//  ContentView.swift
//  Quickstart
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @State private var authViewIsPresented = false

  var body: some View {
    VStack(spacing: 24) {
      UserButton(signedOutContent: {
        Button("Sign in") {
          authViewIsPresented = true
        }
      })

      OrganizationSwitcher()
    }
    .onChange(of: clerk.authCallback?.id, initial: true) { _, id in
      if id != nil { authViewIsPresented = true }
    }
    .onChange(of: clerk.session?.currentTask?.key, initial: true) { _, newValue in
      if newValue != nil {
        authViewIsPresented = true
      }
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView()
        .environment(clerk)
    }
  }
}

#Preview("Signed Out") {
  ContentView()
    .environment(Clerk.preview(.signedOut))
}

#Preview("Signed In") {
  ContentView()
    .environment(Clerk.preview())
}
