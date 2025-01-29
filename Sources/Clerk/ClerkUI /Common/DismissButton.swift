//
//  DismissButton.swift
//
//
//  Created by Mike Pitre on 12/13/23.
//

#if os(iOS)

import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ClerkTheme.self) private var clerkTheme
    
    var beforeDismissAction: (() -> Void)?
    
    var body: some View {
        Button(action: {
            beforeDismissAction?()
            dismiss()
        }, label: {
            Image(systemName: "xmark")
                .imageScale(.small)
                .tint(clerkTheme.colors.textSecondary)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        })
    }
}

#Preview {
    DismissButton()
}

#endif
