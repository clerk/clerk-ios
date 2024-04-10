//
//  DismissButton.swift
//
//
//  Created by Mike Pitre on 12/13/23.
//

#if canImport(SwiftUI)

import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    var body: some View {
        Button(action: {
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
