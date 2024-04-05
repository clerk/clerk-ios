//
//  DemoAppSettingsView.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/11/24.
//

import SwiftUI
import ClerkSDK
import Factory
import KeychainAccess

struct DemoAppSettingsView: View {
    @AppStorage("publishableKey") var publishableKey: String = ""
    @State private var text: String = ""
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Publishable Key") {
                    TextField("Publishable Key", text: $text, prompt: Text("Publishable Key"))
                        .font(.subheadline)
                        .task { text = publishableKey }
                    
                    Button {
                        publishableKey = text
                        Clerk.shared.configure(publishableKey: publishableKey)
                        Task {
                            try? await clerk.load()
                            dismiss()
                        }
                    } label: {
                        Text("Save")
                    }
                    .disabled(text == publishableKey)
                }
                
                Section("Keychain") {
                    Button(role: .destructive) {
                        try? Keychain().removeAll()
                        try? Keychain(server: Clerk.shared.environment.displayConfig.homeUrl, protocolType: .https).removeAll()
                    } label: {
                        Text("Clear Keychain")
                    }
                }
            }
            .navigationTitle("Demo Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                            .imageScale(.small)
                            .padding(10)
                            .background(.ultraThinMaterial, in: .circle)
                    })
                    .tint(.primary)
                }
            }
        }
    }
}

#Preview {
    DemoAppSettingsView()
}
