//
//  DemoAppSettingsView.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/11/24.
//

import SwiftUI
import ClerkSDK
import Factory
import SimpleKeychain

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
                    
                    Button(role: .destructive) {
                        text = ""
                    } label: {
                        Text("Clear")
                    }
                    .disabled(text == "")
                }
            }
            .navigationTitle("Demo Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
                    ProgressView()
                }
            }
        }
    }
    
    @MainActor
    private func resetWithPublishableKey(_ publishableKey: String) async {
        do {
            isLoading = true
            try SimpleKeychain().deleteAll()
            try await clerk.signOut()
            self.publishableKey = publishableKey
            Clerk.shared.configure(publishableKey: publishableKey)
            try await clerk.load()
            isLoading = false
            dismiss()
        } catch {
            dump(error)
        }
    }
}

#Preview {
    DemoAppSettingsView()
}
