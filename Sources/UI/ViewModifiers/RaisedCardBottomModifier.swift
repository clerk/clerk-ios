//
//  RaisedCardBottomModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI

struct RaisedCardBottomModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background()
            .clipShape(UnevenRoundedRectangle(
                cornerRadii: .init(bottomLeading: 8, bottomTrailing: 8),
                style: .continuous
            ))
            .shadow(color: .black.opacity(0.05), radius: 0.5, y: 1)
    }
}

extension View {
    func raisedCardBottom() -> some View {
        modifier(RaisedCardBottomModifier())
    }
}

#Preview {
    ScrollView {
        SecuredByClerkView()
            .frame(maxWidth: .infinity)
    }
    .padding(.vertical)
    .raisedCardBottom()
    .environmentObject(Clerk.mock)
    .environmentObject(ClerkUIState())
}
