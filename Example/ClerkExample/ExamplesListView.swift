//
//  ExamplesListView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/6/23.
//

import SwiftUI
import Clerk

struct ExamplesListView: View {
    @EnvironmentObject var clerk: Clerk
    
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Sign In", destination: SignInExampleView())
                NavigationLink("Endpoint Testing", destination: ContentView())
            }
            .navigationTitle("Clerk Examples")
        }
    }
}

#Preview {
    ExamplesListView()
}
