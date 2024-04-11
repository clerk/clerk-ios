//
//  ClerkPrimaryButtonStyle.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

#if os(iOS)

import SwiftUI

struct ClerkPrimaryButtonStyle: ButtonStyle {
    @Environment(\.clerkTheme) private var clerkTheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 18)
            .font(.footnote.weight(.medium))
            .foregroundStyle(clerkTheme.colors.textOnPrimaryBackground)
            .tint(clerkTheme.colors.textOnPrimaryBackground)
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
            .shadow(radius: 1, y: 1)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

#Preview {
    AsyncButton {
        //
    } label: {
        Text("Continue")
            .padding()
    }
    .buttonStyle(ClerkPrimaryButtonStyle())
}

#endif
