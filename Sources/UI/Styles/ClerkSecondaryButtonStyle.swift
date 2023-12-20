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
            .background(Color(.systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(clerkTheme.colors.borderPrimary, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
            .contentShape(.rect(cornerRadius: 6, style: .continuous))
            .shadow(radius: 0.5, y: 1)
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
