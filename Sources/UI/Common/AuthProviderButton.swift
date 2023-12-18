//
//  AuthProviderButton.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI

struct AuthProviderButton: View {
    let iconImageUrl: String
    var label: String
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
        LazyImage(url: URL(string: iconImageUrl), content: { state in
            if let image = state.image {
                image
                    .resizable()
                    .frame(width: 16, height: 16)
                    .scaledToFit()
            } else {
                Text(label)
                    .lineLimit(1)
            }
        })
        .frame(maxWidth: .infinity)
    }
    
    @MainActor
    @ViewBuilder
    private var regularStyleButton: some View {
        HStack(spacing: 16) {
            LazyImage(url: URL(string: iconImageUrl)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 16, height: 16)
                
            Text("\(label)")
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

extension AuthProviderButton {
    
    init(provider: OAuthProvider, label: String? = nil, style: Style = .regular) {
        self.iconImageUrl = provider.iconImageUrl?.absoluteString ?? ""
        self.style = style
        if let label {
            self.label = label
        } else {
            self.label = style == .regular ? "Continue with \(provider.data.name)" : provider.data.name
        }
    }
    
}

#Preview {
    let limitedProviders: [OAuthProvider] = Array(OAuthProvider.allCases.prefix(2))
    let limitedColumns: [GridItem] = Array(repeating: .init(.flexible()), count: min(limitedProviders.count, limitedProviders.count <= 2 ? 1 : 4))
    
    let manyProviders: [OAuthProvider] = Array(OAuthProvider.allCases)
    let manyColumns: [GridItem] = Array(repeating: .init(.flexible()), count: min(manyProviders.count, manyProviders.count <= 2 ? 1 : 4))
    
    return VStack {
        LazyVGrid(columns: limitedColumns) {
            ForEach(limitedProviders, id: \.self) { provider in
                Button(action: {}) {
                    AuthProviderButton(provider: provider, style: limitedProviders.count <= 2 ? .regular : .compact)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
        }
        
        LazyVGrid(columns: manyColumns) {
            ForEach(manyProviders, id: \.self) { provider in
                Button(action: {}) {
                    AuthProviderButton(provider: provider, style: manyProviders.count <= 2 ? .regular : .compact)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
            }
        }
    }
    .padding()
    
}

#endif
