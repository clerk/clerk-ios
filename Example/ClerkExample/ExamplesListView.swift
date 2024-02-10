//
//  ExamplesListView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/6/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK

struct ExamplesListView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Tap the user button to get started.")
            }
            .navigationTitle("Clerk Examples")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    UserButton()
                }
            }
        }
    }
}

#Preview {
    ExamplesListView()
}

#endif


