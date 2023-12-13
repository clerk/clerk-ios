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
    let hidden: Bool
    
    func body(content: Content) -> some View {
        if hidden {
            content
        } else {
            content
                .overlay(alignment: alignment) {
                    DismissButton()
                        .padding()
                }
        }
        
    }
    
}

extension View {
    public func dismissButtonOverlay(alignment: Alignment = .topTrailing, hidden: Bool = false) -> some View {
        modifier(DismissButtonOverlayModifier(alignment: alignment, hidden: hidden))
    }
}

#Preview {
    Color(.systemBackground)
        .dismissButtonOverlay()
}
