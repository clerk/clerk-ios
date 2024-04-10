//
//  CheckBoxView.swift
//
//
//  Created by Mike Pitre on 12/19/23.
//

#if canImport(SwiftUI)

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
                        #if !os(tvOS)
                        .foregroundStyle(Color(.systemBackground))
                        #endif
                        .shadow(radius: 1, y: 1)
                        .padding(4)
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                #if !os(tvOS)
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
                                #endif
                                .background(clerkTheme.colors.primary)
                                .clipShape(.rect(cornerRadius: 4, style: .continuous))
                                .shadow(radius: 1, y: 1)
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

#endif
