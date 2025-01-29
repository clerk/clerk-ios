//
//  DismissButtonOverlay.swift
//
//
//  Created by Mike Pitre on 11/22/23.
//

#if os(iOS)

import Foundation
import SwiftUI

struct DismissButtonOverlayModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let alignment: Alignment
    let hidden: Bool
    let beforeDismissAction: (() -> Void)?
    
    func body(content: Content) -> some View {
        if hidden {
            content
        } else {
            content
                .overlay(alignment: alignment) {
                    DismissButton(beforeDismissAction: beforeDismissAction)
                        .padding()
                }
        }
        
    }
    
}

extension View {
    public func dismissButtonOverlay(alignment: Alignment = .topTrailing, hidden: Bool = false, beforeDismissAction: (() -> Void)? = nil) -> some View {
        modifier(DismissButtonOverlayModifier(alignment: alignment, hidden: hidden, beforeDismissAction: beforeDismissAction))
    }
}

#Preview {
    Text("Hello, World!")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dismissButtonOverlay()
}

#endif
