//
//  EnvironmentValues.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//


import Foundation
import SwiftUI
import Clerk

extension EnvironmentValues {
    #if os(iOS)
    @Entry var clerkUIState: ClerkUIState.default
    @Entry var authViewConfig = AuthView.Config()
    #endif
}

extension ClerkUIState {
    static let default = ClerkUIState()
}

