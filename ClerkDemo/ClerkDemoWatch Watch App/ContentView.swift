//
//  ContentView.swift
//  ClerkDemoWatch Watch App
//
//  Created by Mike Pitre on 4/11/24.
//

import SwiftUI
import ClerkSDK

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack {
                Text("Clerk UI components are only supported on iOS (iPhone, iPad, Mac Catalyst), but you can still use the Clerk SDK to interact with the Clerk API on other platforms.")
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
