//
//  DismissButton.swift
//
//
//  Created by Mike Pitre on 12/13/23.
//

#if canImport(UIKit)

import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(action: {
            dismiss()
        }, label: {
            Image(systemName: "xmark")
                .imageScale(.small)
                .tint(.secondary)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        })
    }
}

#Preview {
    DismissButton()
}

#endif
