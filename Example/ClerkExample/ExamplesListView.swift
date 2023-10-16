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
    
    @State private var isDeletingClient = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Components") {
                    Button {
                        clerk.signInIsPresented = true
                    } label: {
                        Text("Sign In")
                    }
                    
                    Button {
                        clerk.signUpIsPresented = true
                    } label: {
                        Text("Sign Up")
                    }
                }
                
                Section("Settings") {
                    deleteClientButton
                }
            }
            .navigationTitle("Clerk Examples")
        }
    }
    
    @ViewBuilder
    private var deleteClientButton: some View {
        Button(action: {
            Task { await deleteClientAction() }
        }, label: {
            ZStack(alignment: .leading) {
                Text("Delete Client").opacity(isDeletingClient ? 0 : 1)
                ProgressView().opacity(isDeletingClient ? 1 : 0)
            }
        })
        .disabled(isDeletingClient)
    }
    
    private func deleteClientAction() async {
        isDeletingClient = true
        
        do {
            try await clerk
                .client
                .destroy()

            isDeletingClient = false
        } catch {
            dump(error)
            isDeletingClient = false
        }
    }
}

#Preview {
    ExamplesListView()
}

#endif


