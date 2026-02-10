//
//  ContentView.swift
//  CustomFlows
//

import ClerkKit
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk

  var body: some View {
    if clerk.user != nil {
      ProfileView()
    } else {
      AuthFlowListView()
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
