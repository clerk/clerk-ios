//
//  ClerkThemes.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if os(iOS)

import Foundation
import SwiftUI

extension ClerkTheme {

    @MainActor
    public static let `default`: ClerkTheme = .init(
        colors: .default,
        fonts: .default,
        design: .default
    )

    @MainActor
    public static let clerk: ClerkTheme = .init(
        colors: .init(
            primary: Color(.clerkPrimary),
            danger: Color(.clerkDanger),
            primaryForeground: Color(.clerkTextOnPrimaryBackground),
            neutral: Color(.clerkNeutral)
        ),
        design: .init(
            borderRadius: 8.0
        )
    )
}

extension EnvironmentValues {
    public var clerkTheme: ClerkTheme {
        get { self[ClerkThemeEnvironmentKey.self] }
        set { self[ClerkThemeEnvironmentKey.self] = newValue }
    }
}

// Create a custom environment key
private struct ClerkThemeEnvironmentKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: ClerkTheme = .default
}

#endif
