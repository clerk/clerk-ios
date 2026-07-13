//
//  SharedSessionSyncVersion.swift
//  Clerk
//

import Foundation

struct SharedSessionSyncVersion: Hashable {
  static let initial = SharedSessionSyncVersion(rawValue: "")

  let rawValue: String

  static func makeWriteRevision() -> SharedSessionSyncVersion {
    SharedSessionSyncVersion(rawValue: UUID().uuidString)
  }
}
