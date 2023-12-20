//
//  ClerkBottomBrandingModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI

struct ClerkBottomBrandingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, content: {
                SecuredByClerkView()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background()
            })
//            .keyboardAvoidingBottomView {
//                SecuredByClerkView()
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background()
//            }
    }
}

extension View {
    public func clerkBottomBranding() -> some View {
        modifier(ClerkBottomBrandingModifier())
    }
}

#Preview {
    ScrollView {
        Text("Hello, World!")
    }
    .clerkBottomBranding()
}
