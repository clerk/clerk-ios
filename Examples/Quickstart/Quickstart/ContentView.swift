//
//  ContentView.swift
//  Quickstart
//

import ClerkJSCore
import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @SwiftUI.Environment(ClerkKit.Clerk.self) private var clerk
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
    .onOpenURL { url in
      Task {
        do {
          try await clerk.handle(url)
        } catch {
          print("Failed to handle Clerk URL: \(error.localizedDescription)")
        }
      }
    }
    .task {
      for await event in clerk.auth.events {
        switch event {
        case .signInNeedsContinuation, .signUpNeedsContinuation:
          authViewIsPresented = true
        default:
          break
        }
      }
    }
    .onChange(of: clerk.session?.tasks, initial: true) { _, newValue in
      if newValue?.isEmpty == false {
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
    .environment(ClerkKit.Clerk.preview { preview in
      preview.isSignedIn = false
    })
    .environment(ClerkJSCore.Clerk(publishableKey: "pk_test_preview"))
}

#Preview("Signed In") {
  ContentView()
    .environment(ClerkKit.Clerk.preview())
    .environment(ClerkJSCore.Clerk(publishableKey: "pk_test_preview"))
}
