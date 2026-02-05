//
//  ContentView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @State private var showLoginSheet = false
  @State private var router = Router()

  var body: some View {
    ZStack {
      if clerk.user != nil {
        HomeView()
      } else {
        WelcomeView(showLoginSheet: $showLoginSheet)
      }
    }
    .sheet(isPresented: $showLoginSheet, onDismiss: {
      router.authPath = NavigationPath()
      router.showOTPVerification = false
    }) {
      LoginView()
        .environment(router)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
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
