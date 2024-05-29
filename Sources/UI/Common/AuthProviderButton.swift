//
//  AuthProviderButton.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if os(iOS)

import SwiftUI
import NukeUI

struct AuthProviderButton: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let provider: ExternalProvider
    let label: String
    var style: Style = .regular
    
    enum Style {
        case compact
        case regular
    }
    
    var body: some View {
        switch style {
        case .compact: compactStyleButton
        case .regular: regularStyleButton
        }
    }
    
    @MainActor
    @ViewBuilder
    private var compactStyleButton: some View {
        AuthProviderIcon(provider: provider)
            .frame(width: 16, height: 16)
    }
    
    @MainActor
    @ViewBuilder
    private var regularStyleButton: some View {
        HStack(spacing: 16) {
            AuthProviderIcon(provider: provider)
                .frame(width: 16, height: 16)
                
            Text("\(label)")
                .lineLimit(1)
        }
    }
}

extension AuthProviderButton {
    
    init(provider: ExternalProvider, label: String? = nil, style: Style = .regular) {
        self.provider = provider
        self.style = style
        if let label {
            self.label = label
        } else {
            self.label = provider.info.name
        }
    }
    
}

#Preview {
    let limitedProviders: [ExternalProvider] = Array(ExternalProvider.allCases.prefix(2))
    let limitedColumns: [GridItem] = Array(repeating: .init(.flexible()), count: min(limitedProviders.count, limitedProviders.count <= 2 ? 1 : 4))
    
    let manyProviders: [ExternalProvider] = Array(ExternalProvider.allCases)
    let manyColumns: [GridItem] = Array(repeating: .init(.flexible()), count: min(manyProviders.count, manyProviders.count <= 2 ? 1 : 4))
    
    return VStack {
        LazyVGrid(columns: limitedColumns) {
            ForEach(limitedProviders, id: \.self) { provider in
                Button(action: {}) {
                    AuthProviderButton(provider: provider, style: limitedProviders.count <= 2 ? .regular : .compact)
                        .clerkStandardButtonPadding()
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
        }
        
        LazyVGrid(columns: manyColumns) {
            ForEach(manyProviders, id: \.self) { provider in
                Button(action: {}) {
                    AuthProviderButton(provider: provider, style: manyProviders.count <= 2 ? .regular : .compact)
                        .clerkStandardButtonPadding()
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
        }
    }
    .padding()
    
}

#endif
