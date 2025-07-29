//
//  KeychainConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 3/24/25.
//

import Foundation

/// A configuration object that can be passed to `Clerk.configure()` to customize keychain behavior.
public struct KeychainConfig: Sendable {

    /// Name of the service under which to save items. Defaults to the bundle identifier.
    public let service: String

    /// Access group for sharing Keychain items.
    public let accessGroup: String?

    /// Initializes a ``KeychainConfig`` instance.
    /// - Parameters:
    ///   - service: Name of the service under which to save items. Defaults to the bundle identifier.
    ///   - accessGroup: Access group for sharing Keychain items.
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }
}
