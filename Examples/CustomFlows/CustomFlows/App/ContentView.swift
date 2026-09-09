import ClerkKit
import ClerkKitUI
import SwiftUI

@MainActor @Observable
final class CustomFlowFeedback {
  var error: String?
  var continuation: AuthView.Mode?
}

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback

  var body: some View {
    Group {
      if clerk.user != nil, clerk.session?.status == .active, clerk.session?.currentTask == nil {
        ProfileView()
      } else if clerk.session?.currentTask != nil {
        AuthView(isDismissible: false)
      } else {
        AuthFlowListView()
      }
    }
    .alert("Unable to complete authentication", isPresented: Binding(
      get: { feedback.error != nil },
      set: { if !$0 { feedback.error = nil } }
    )) {
      Button("OK") { feedback.error = nil }
    } message: {
      Text(feedback.error ?? "")
    }
    .sheet(isPresented: Binding(
      get: { feedback.continuation != nil },
      set: { if !$0 { feedback.continuation = nil } }
    )) {
      AuthView(mode: feedback.continuation ?? .signInOrUp)
    }
    .onChange(of: clerk.authCallback?.id, initial: true) { _, id in
      if id != nil { feedback.continuation = .signInOrUp }
    }
  }
}

#Preview("Signed Out") {
  ContentView().environment(Clerk.preview(.signedOut)).environment(CustomFlowFeedback())
}

#Preview("Signed In") {
  ContentView().environment(Clerk.preview()).environment(CustomFlowFeedback())
}
