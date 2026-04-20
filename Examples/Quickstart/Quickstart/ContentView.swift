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
    VStack {
      UserButton(signedOutContent: {
        Button("Sign in") {
          authViewIsPresented = true
        }
      })
    }
    .onOpenURL { url in
      Task {
        do {
          try await clerk.handle(url)
        } catch {
          print("Failed to handle Clerk URL: \(error.localizedDescription)")
        }
      }
    }
    .onAuthPresentationRequirement { _ in
      authViewIsPresented = true
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
