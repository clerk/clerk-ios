//
//  ClerkDemoSettingsModifier.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/11/24.
//

import SwiftUI
import ClerkSDK

struct ClerkDemoSettingsModifier: ViewModifier {
    @State private var isPresented: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                Button {
                    isPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                        .foregroundStyle(.background)
                        .padding(8)
                        .background(.primary)
                        .clipShape(.circle)
                }
                .tint(.primary)
                .padding()
            }
            .sheet(isPresented: $isPresented, content: {
                DemoAppSettingsView()
            })
    }
}

extension View {
    func demoSettings() -> some View {
        modifier(ClerkDemoSettingsModifier())
    }
}

#Preview {
    HomeView()
        .demoSettings()
}
