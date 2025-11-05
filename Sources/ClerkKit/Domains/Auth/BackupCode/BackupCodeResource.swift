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
  public var id: String

  /// The generated set of backup codes.
  public var codes: [String]

  /// The date when the backup codes were created.
  public var createdAt: Date

  /// The date when the backup codes were last updated.
  public var updatedAt: Date
}

