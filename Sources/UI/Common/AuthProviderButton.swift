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
        LazyImage(url: URL(string: iconImageUrl), content: { state in
            if let image = state.image {
                image
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Text(label)
                    .lineLimit(1)
            }
        })
        .frame(minHeight: 48)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(.systemFill), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    @MainActor
    @ViewBuilder
    private var regularStyleButton: some View {
        HStack(spacing: 16) {
            LazyImage(url: URL(string: iconImageUrl))
                .frame(width: 20, height: 20)
            Text("Continue with \(label)")
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal)
        .frame(minHeight: 42)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(.systemFill), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension AuthProviderButton {
    
    init(provider: OAuthProvider, style: Style = .regular) {
        self.iconImageUrl = provider.iconImageUrl?.absoluteString ?? ""
        self.label = provider.data.name
        self.style = style
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
                AuthProviderButton(provider: provider, style: limitedProviders.count <= 2 ? .regular : .compact)
                    .font(.footnote)
            }
        }
        
        LazyVGrid(columns: manyColumns) {
            ForEach(manyProviders, id: \.self) { provider in
                AuthProviderButton(provider: provider, style: manyProviders.count <= 2 ? .regular : .compact)
                    .font(.footnote)
            }
        }
    }
    .padding()
    
}

#endif
