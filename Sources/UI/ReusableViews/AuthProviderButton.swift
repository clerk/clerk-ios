//
//  AuthProviderButton.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if !os(macOS)

import SwiftUI

struct AuthProviderButton: View {
    let image: String
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
    
    private var compactStyleButton: some View {
        Image(systemName: image)
            .padding(16)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(.systemFill), lineWidth: 1)
            }
            .aspectRatio(1, contentMode: .fit)
    }
    
    private var regularStyleButton: some View {
        HStack(spacing: 16) {
            Image(systemName: image)
            Text("Continue with \(label.capitalized)")
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

struct AuthProviderButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            VStack {
                AuthProviderButton(image: "tornado.circle.fill", label: "GitHub")
                AuthProviderButton(image: "shield.lefthalf.filled", label: "Google")
            }
            
            HStack {
                AuthProviderButton(image: "tornado.circle.fill", label: "GitHub", style: .compact)
                AuthProviderButton(image: "shield.lefthalf.filled", label: "Google", style: .compact)
            }
        }
        .padding()
    }
}

#endif
