//
//  ContentView.swift
//  WatchExampleApp
//
//  Created on 2025-01-27.
//

import ClerkKit
import ClerkKitUI
import os
import SwiftUI

private let watchSyncLog = Logger(subsystem: "com.clerk.WatchExampleApp", category: "watch-sync")

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
    .onAppear {
      watchSyncLog.notice("clerk-watch-sync phone ui user=\(Clerk.shared.userId ?? "nil", privacy: .public)")
    }
    .onChange(of: Clerk.shared.userId) { _, id in
      watchSyncLog.notice("clerk-watch-sync phone ui user=\(id ?? "nil", privacy: .public)")
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
