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

  var body: some View {
    Group {
      if clerk.user != nil {
        HomeView()
      } else {
        WelcomeView(showLoginSheet: $showLoginSheet)
      }
    }
    .sheet(isPresented: $showLoginSheet) {
      LoginView()
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
