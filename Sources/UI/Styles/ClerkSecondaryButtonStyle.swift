//
//  ClerkSecondaryButtonStyle.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

#if canImport(UIKit)

import SwiftUI

struct ClerkSecondaryButtonStyle: ButtonStyle {
    @Environment(\.clerkTheme) private var clerkTheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.medium))
            .foregroundStyle(clerkTheme.colors.textPrimary)
            .background()
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(clerkTheme.colors.borderPrimary, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
            .contentShape(.rect(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 0.5, y: 1)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

#Preview {
    Button {
        //
    } label: {
        Text("Continue")
            .padding()
    }
    .buttonStyle(ClerkSecondaryButtonStyle())
}

#endif
