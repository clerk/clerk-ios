//
//  ContentView.swift
//  WatchExampleApp
//
//  Created on 2025-01-27.
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @State private var authViewIsPresented = false

  var body: some View {
    VStack {
      UserButton(signedOutContent: {
        Button("Sign in") {
          authViewIsPresented = true
        }
      })
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
