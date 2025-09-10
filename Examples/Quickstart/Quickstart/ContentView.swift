//
//  ContentView.swift
//  Quickstart
//
//  Created by Mike Pitre on 7/30/25.
//

import Clerk
import SwiftUI

struct ContentView: View {
  @Environment(\.clerk) private var clerk
  @State private var authViewIsPresented = false

  var body: some View {
    VStack {
      if clerk.user != nil {
        UserButton()
          .frame(width: 36, height: 36)
      } else {
        Button("Sign in") {
          authViewIsPresented = true
        }
      }
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView()
    }
  }
}

#Preview {
  ContentView()
}
