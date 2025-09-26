//
//  View+ClerkPreviewMock.swift
//  Clerk
//
//  Created by Mike Pitre on 9/24/25.
//

#if os(iOS)

import Clerk
import SwiftUI

private struct ClerkPreviewMockModifier: ViewModifier {
    let configure: @Sendable (MockAPIClient) -> Void

    func body(content: Content) -> some View {
        content
            .task(priority: .high) {
                let mock = MockAPIClient()
                configure(mock)
                Clerk.shared.use(apiClient: mock)
            }
            .onDisappear {
                Clerk.shared.resetAPIClientToDefault()
            }
    }
}

extension View {
    func clerkPreviewMock(
        _ configure: @escaping @Sendable (MockAPIClient) -> Void
    ) -> some View {
        modifier(ClerkPreviewMockModifier(configure: configure))
    }
}

#endif


