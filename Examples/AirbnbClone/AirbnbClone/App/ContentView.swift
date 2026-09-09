//
//  ContentView.swift
//  AirbnbClone
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(AirbnbAuthFeedback.self) private var feedback
  @State private var showLoginSheet = false
  @State private var router = Router()

  var body: some View {
    ZStack {
      if clerk.session?.currentTask != nil || feedback.continuation != nil || clerk.authCallback != nil {
        AuthView(mode: feedback.continuation ?? .signInOrUp, isDismissible: false,
                 onAuthComplete: { feedback.continuation = nil })
      } else if clerk.session?.status == .active, clerk.user != nil {
        HomeView()
      } else {
        WelcomeView(showLoginSheet: $showLoginSheet)
      }
    }
    .onChange(of: feedback.continuation != nil || clerk.authCallback != nil || clerk.session?.currentTask != nil) { _, active in
      if active { showLoginSheet = false }
    }
    .onChange(of: clerk.session?.status == .active && clerk.session?.currentTask == nil && clerk.user != nil) { _, complete in
      if complete { showLoginSheet = false }
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
    .environment(Clerk.preview(.signedOut)).environment(AirbnbAuthFeedback())
}

#Preview("Signed In") {
  ContentView()
    .environment(Clerk.preview()).environment(AirbnbAuthFeedback())
}
