//
//  ContentView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/2/23.
//

import SwiftUI
import Clerk

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(Clerk.hello)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
