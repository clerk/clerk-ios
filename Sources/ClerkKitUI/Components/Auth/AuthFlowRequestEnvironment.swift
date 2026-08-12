//
//  AuthFlowRequestEnvironment.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

extension EnvironmentValues {
  @Entry var authFlowRequestOwnerId: UUID?
}

#endif
