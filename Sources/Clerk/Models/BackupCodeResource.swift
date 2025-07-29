//
//  BackupCodeResource.swift
//  Clerk
//
//  Created by Mike Pitre on 6/12/25.
//

import Foundation

/// An interface that represents a backup code.
public struct BackupCodeResource: Identifiable, Codable, Hashable, Equatable, Sendable {

    /// The unique identifier for the set of backup codes.
    public let id: String

    /// The generated set of backup codes.
    public let codes: [String]

    /// The date when the backup codes were created.
    public let createdAt: Date

    /// The date when the backup codes were last updated.
    public let updatedAt: Date
}

extension BackupCodeResource {

    static var mock: Self {
        .init(
            id: "1",
            codes: [
                "abcd",
                "efgh",
                "ijkl",
                "mnop",
                "qrst",
                "uvwx",
                "yz"
            ],
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
    }

}
