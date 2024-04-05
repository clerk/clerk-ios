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
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Publishable Key") {
                    TextField("Publishable Key", text: $text, prompt: Text("Publishable Key"))
                        .font(.subheadline)
                        .task { text = publishableKey }
                    
                    Button {
                        Task { await resetWithPublishableKey(text) }
                    } label: {
                        Text("Save")
                    }
                    .disabled(text == publishableKey)
                }
                
                Section("Reset") {
                    Button(role: .destructive) {
                        Task { await resetWithPublishableKey("") }
                    } label: {
                        Text("Reset")
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
            .overlay {
                if isLoading {
                    ZStack {
                        Color(.systemBackground).opacity(0.5).ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func resetWithPublishableKey(_ publishableKey: String) async {
        isLoading = true
        try? await clerk.client?.destroy()
        try? Keychain().removeAll()
        if let environment = clerk.environment {
            try? Keychain(server: environment.displayConfig.homeUrl, protocolType: .https)
                .removeAll()
        }
        self.publishableKey = publishableKey
        Clerk.shared.configure(publishableKey: publishableKey)
        try? await clerk.load()
        isLoading = false
        dismiss()
    }
}

#Preview {
    DemoAppSettingsView()
}
