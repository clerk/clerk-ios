//
//  DismissButtonOverlay.swift
//
//
//  Created by Mike Pitre on 11/22/23.
//

import Foundation
import SwiftUI

struct DismissButtonOverlayModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let alignment: Alignment
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                Button(action: {
                    dismiss()
                }, label: {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .tint(.secondary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                })
                .padding(.vertical)
                .padding(.horizontal, 30)
            }
    }
    
}

extension View {
    public func dismissButtonOverlay(alignment: Alignment = .topTrailing) -> some View {
        modifier(DismissButtonOverlayModifier(alignment: alignment))
    }
}

#Preview {
    Color(.systemBackground)
        .dismissButtonOverlay()
}
