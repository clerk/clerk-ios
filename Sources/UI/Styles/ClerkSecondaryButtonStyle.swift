//
//  ClerkSecondaryButtonStyle.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

import SwiftUI

struct ClerkSecondaryButtonStyle: ButtonStyle {
    @Environment(\.clerkTheme) private var clerkTheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: ClerkStyleConstants.textMinHeight)
            .font(.footnote.weight(.medium))
            .foregroundStyle(clerkTheme.colors.gray700)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(clerkTheme.colors.borderPrimary, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
            .contentShape(.rect(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 0, x: 0, y: 0.2)
            .shadow(color: .black.opacity(0.02), radius: 0, x: 0, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 0, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

#Preview {
    Button {
        //
    } label: {
        Text("Continue")
    }
    .buttonStyle(ClerkSecondaryButtonStyle())
}
