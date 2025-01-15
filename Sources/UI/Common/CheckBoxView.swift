//
//  CheckBoxView.swift
//
//
//  Created by Mike Pitre on 12/19/23.
//

#if os(iOS)

import SwiftUI

struct CheckBoxView: View {
    @Environment(ClerkTheme.self) private var clerkTheme
    
    @Binding var isSelected: Bool
    
    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(clerkTheme.colors.borderPrimary, lineWidth: 1)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(.systemBackground))
                        .shadow(radius: 1, y: 1)
                        .padding(4)
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .background(
                                    LinearGradient(
                                        stops: [
                                            Gradient.Stop(color: Color(.systemBackground).opacity(0.1), location: 0.00),
                                            Gradient.Stop(color: Color(.systemBackground).opacity(0), location: 1.00),
                                        ],
                                        startPoint: UnitPoint(x: 0.5, y: 0),
                                        endPoint: UnitPoint(x: 0.5, y: 1)
                                    )
                                )
                                .background(clerkTheme.colors.primary)
                                .clipShape(.rect(cornerRadius: 4, style: .continuous))
                                .shadow(radius: 1, y: 1)
                        }
                        .transition(.scale)
                }
            }
            .contentShape(.rect)
            .animation(.bouncy.speed(2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CheckBoxView(isSelected: .constant(true))
        .frame(width: 40, height: 40)
        .environment(ClerkTheme.clerkDefault)
}

#endif
