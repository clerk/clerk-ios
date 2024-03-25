//
//  DemoAppSettingsView.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/11/24.
//

import SwiftUI
import ClerkSDK
import Factory

struct DemoAppSettingsView: View {
    @AppStorage("publishableKey") var publishableKey: String = ""
    @State private var text: String = ""
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {                
                TextField("Publishable Key", text: $text, prompt: Text("Publishable Key"))
                    .font(.subheadline)
                    .task { text = publishableKey }
                
                Button {
                    publishableKey = text
                    clerk.load(publishableKey: publishableKey)
                    dismiss()
                } label: {
                    Text("Save")
                }
                .disabled(text == publishableKey)
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
