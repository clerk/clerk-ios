//
//  KeychainConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 3/24/25.
//

import Foundation
import SimpleKeychain

/// A configuration object that can be passed to `Clerk.configure()` to customize keychain behavior.
public struct KeychainConfig: Sendable {

    /// Name of the service under which to save items. Defaults to the bundle identifier.
    public let service: String

    /// Access group for sharing Keychain items.
    public let accessGroup: String?

    /// Accessibility type the stored items will have
    public let accessibility: Accessibility

    /// Whether the items should be synchronized through iCloud
    public let synchronizable: Bool

    /// Initializes a ``KeychainConfig`` instance.
    /// - Parameters:
    ///   - service: Name of the service under which to save items. Defaults to the bundle identifier.
    ///   - accessGroup: Access group for sharing Keychain items.
    ///   - accessibility: ``Accessibility`` type the stored items will have
    ///   - synchronizable: Whether the items should be synchronized through iCloud
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "",
        accessGroup: String? = nil,
        accessibility: Accessibility = .afterFirstUnlockThisDeviceOnly,
        synchronizable: Bool = false
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
        self.synchronizable = synchronizable
    }
}
