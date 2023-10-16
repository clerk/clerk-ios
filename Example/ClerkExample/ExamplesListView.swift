//
//  ExamplesListView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/6/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct ExamplesListView: View {
    @EnvironmentObject private var clerk: Clerk
    
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Sign In / Sign Up", destination: SignInExampleView())
                
                Button(action: {
                    Task { await deleteClientAction() }
                }, label: {
                    Text("Delete Client")
                })
            }
            .navigationTitle("Clerk Examples")
        }
    }
    
    private func deleteClientAction() async {
        do {
            try await clerk
                .client
                .destroy()
        } catch {
            dump(error)
        }
    }
}

#Preview {
    ExamplesListView()
}

#endif


