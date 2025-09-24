//
//  View+ClerkPreviewMock.swift
//  Clerk
//
//  Created by Mike Pitre on 9/24/25.
//

#if os(iOS)

import SwiftUI

private struct ClerkPreviewMockModifier: ViewModifier {
    let configure: @Sendable (MockAPIClient) async throws -> Void

    func body(content: Content) -> some View {
        content
            .task(priority: .high) {
                do {
                    let mock = MockAPIClient()
                    try await configure(mock)
                    await Clerk.shared.use(apiClient: mock)
                } catch {
                    assertionFailure("Failed to configure MockAPIClient for preview: \(error)")
                }
            }
            .onDisappear {
                Task {
                    await Clerk.shared.resetAPIClientToDefault()
                }
            }
    }
}

extension View {
    func clerkPreviewMock(
        _ configure: @escaping @Sendable (MockAPIClient) async throws -> Void
    ) -> some View {
        modifier(ClerkPreviewMockModifier(configure: configure))
    }
}

#endif


