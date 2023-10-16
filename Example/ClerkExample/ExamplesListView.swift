//
//  ExamplesListView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/6/23.
//

#if canImport(UIKit)

import SwiftUI

struct ExamplesListView: View {
    
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

struct ExamplesListView_Previews: PreviewProvider {
    static var previews: some View {
        ExamplesListView()
    }
}

#endif


