//
//  CheckBoxView.swift
//
//
//  Created by Mike Pitre on 12/19/23.
//

import SwiftUI

struct CheckBoxView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
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
                        .shadow(color: Color(.systemBackground).opacity(0.14), radius: 0.5, x: 0, y: 0)
                        .shadow(color: Color(.systemBackground).opacity(0.08), radius: 1, x: 0, y: 1.5)
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
                                .shadow(color: Color(red: 0.18, green: 0.19, blue: 0.22), radius: 0, x: 0, y: 0)
                                .shadow(color: Color(red: 0.13, green: 0.16, blue: 0.21).opacity(0.2), radius: 1.5, x: 0, y: 2)
                                .shadow(color: Color(.systemBackground).opacity(0.24), radius: 0.5, x: 0, y: 1)
                        }
                        .transition(.scale)
                }
            }
            .animation(.bouncy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CheckBoxView(isSelected: .constant(true))
        .frame(width: 40, height: 40)
}
