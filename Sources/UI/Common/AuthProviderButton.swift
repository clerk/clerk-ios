//
//  AuthProviderButton.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI
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
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
            } else {
                Color(.secondarySystemBackground)
                    .clipShape(.circle)
            }
        })
        .frame(width: 16, height: 16)
    }
    
    @MainActor
    @ViewBuilder
    private var regularStyleButton: some View {
        HStack(spacing: 16) {
            LazyImage(url: URL(string: iconImageUrl)) { state in
                if let image = state.image {
                    image
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.primary)
                } else {
                    Color(.secondarySystemBackground)
                        .clipShape(.circle)
                }
            }
            .frame(width: 16, height: 16)
                
            Text("\(label)")
                .lineLimit(1)
        }
    }
}

extension AuthProviderButton {
    
    init(provider: ExternalProvider, label: String? = nil, style: Style = .regular) {
        self.iconImageUrl = provider.iconImageUrl?.absoluteString ?? ""
        self.style = style
        if let label {
            self.label = label
        } else {
            self.label = provider.data.name
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
