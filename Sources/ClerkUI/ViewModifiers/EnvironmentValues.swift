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
    @Entry var clerkUIState = ClerkUIState()
    @Entry var authViewConfig = AuthView.Config()
    #endif
}

