//
//  ClerkDangerButtonStyle.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

import SwiftUI

struct ClerkDangerButtonStyle: ButtonStyle {
    @Environment(\.clerkTheme) private var clerkTheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(clerkTheme.colors.textOnPrimaryBackground)
            .frame(minHeight: ClerkStyleConstants.textMinHeight)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
            .background(clerkTheme.colors.red500)
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
            .shadow(color: Color(red: 0.94, green: 0.27, blue: 0.27), radius: 0, x: 0, y: 0)
            .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 2)
            .shadow(color: .black.opacity(0.08), radius: 0.5, x: 0, y: 1)
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
    .buttonStyle(ClerkDangerButtonStyle())
}
