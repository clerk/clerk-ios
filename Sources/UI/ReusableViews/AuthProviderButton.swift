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
        LazyImage(url: URL(string: iconImageUrl))
            .frame(width: 20, height: 20)
            .padding(16)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(.systemFill), lineWidth: 1)
            }
            .aspectRatio(1, contentMode: .fit)
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
        .padding(.vertical, 12)
        .padding(.horizontal)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(.systemFill), lineWidth: 1)
        }
        
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
    VStack {
        VStack {
            AuthProviderButton(provider: .apple)
            AuthProviderButton(provider: .google)
        }
        
        HStack {
            AuthProviderButton(provider: .apple, style: .compact)
            AuthProviderButton(provider: .google, style: .compact)
        }
    }
    .padding()
}

#endif
