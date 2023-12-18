//
//  ClerkPrimaryButtonStyle.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

import SwiftUI

struct ClerkPrimaryButtonStyle: ButtonStyle {
    @Environment(\.clerkTheme) private var clerkTheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: ClerkStyleConstants.textMinHeight)
            .font(.footnote.weight(.medium))
            .foregroundStyle(clerkTheme.colors.textOnPrimaryBackground)
            .tint(clerkTheme.colors.textOnPrimaryBackground)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .white.opacity(0.1), location: 0.00),
                        Gradient.Stop(color: .white.opacity(0), location: 1.00),
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)
                )
            )
            .background(clerkTheme.colors.primary)
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
            .contentShape(.rect(cornerRadius: 6, style: .continuous))
            .shadow(color: Color(red: 0.18, green: 0.19, blue: 0.22), radius: 0, x: 0, y: 0)
            .shadow(color: Color(red: 0.13, green: 0.16, blue: 0.21).opacity(0.2), radius: 1.5, x: 0, y: 2)
            .shadow(color: .black.opacity(0.24), radius: 0.5, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

#Preview {
    AsyncButton {
        //
    } label: {
        Text("Continue")
    }
    .buttonStyle(ClerkPrimaryButtonStyle())
}
