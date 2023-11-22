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
                Button("", systemImage: "xmark", action: dismiss.callAsFunction)
                    .imageScale(.small)
                    .padding(.vertical)
                    .padding(.horizontal, 30)
                    .tint(.secondary)
            }
    }
    
}

extension View {
    public func dismissButtonOverlay(alignment: Alignment = .topTrailing) -> some View {
        modifier(DismissButtonOverlayModifier(alignment: alignment))
    }
}
