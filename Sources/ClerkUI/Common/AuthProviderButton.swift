//
//  AuthProviderButton.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if os(iOS)

import SwiftUI
import Clerk

struct AuthProviderButton: View {
    let provider: OAuthProvider
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
    
    @ViewBuilder
    private var compactStyleButton: some View {
        if provider.iconImageUrl() != nil {
            AuthProviderIcon(provider: provider)
                .frame(width: 16, height: 16)
        }
    }
    
    @ViewBuilder
    private var regularStyleButton: some View {
        HStack(spacing: 16) {
            if provider.iconImageUrl() != nil {
                AuthProviderIcon(provider: provider)
                    .frame(width: 16, height: 16)
            }
                
            Text("\(label)")
                .lineLimit(1)
        }
    }
}

extension AuthProviderButton {
    
    init(provider: OAuthProvider, label: String? = nil, style: Style = .regular) {
        self.provider = provider
        self.style = style
        if let label {
            self.label = label
        } else {
            self.label = provider.name
        }
    }
    
}

#Preview {
    VStack {
        AuthProviderButton(provider: .apple, style: .regular)
            .clerkStandardButtonPadding()
        AuthProviderButton(provider: .apple, style: .compact)
            .clerkStandardButtonPadding()
    }
}

#endif
