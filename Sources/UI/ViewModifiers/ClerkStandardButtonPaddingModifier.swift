//
//  ClerkStandardButtonPaddingModifier.swift
//
//
//  Created by Mike Pitre on 1/17/24.
//

import SwiftUI

struct ClerkStandardButtonPaddingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

extension View {
    func clerkStandardButtonPadding() -> some View {
        modifier(ClerkStandardButtonPaddingModifier())
    }
}

#Preview {
    Button {
        //
    } label: {
        Text("Button")
            .clerkStandardButtonPadding()
    }
    .buttonStyle(ClerkPrimaryButtonStyle())
}
