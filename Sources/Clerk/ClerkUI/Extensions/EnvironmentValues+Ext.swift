//
//  EnvironmentValues+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if canImport(SwiftUI)

import Foundation
import SwiftUI

extension EnvironmentValues {
  // MARK: - Public
  @Entry public var clerk = Clerk.shared
  @Entry public var clerkTheme = ClerkTheme.default
  
  // MARK: - Internal
  @Entry var authState = AuthState()
}

#endif
