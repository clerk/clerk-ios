//
//  SharedSessionIdentityEvent.swift
//  Clerk
//

import CryptoKit
import Foundation

struct SharedSessionNamespace: Equatable {
  static let protocolIdentifier = "clerk.shared-session-sync.v2"

  let fingerprint: String

  init(frontendApiUrl: String, publishableKey: String) {
    var normalizedFrontendApiUrl = frontendApiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    while normalizedFrontendApiUrl.hasSuffix("/") {
      normalizedFrontendApiUrl.removeLast()
    }
    let normalizedPublishableKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
    let seed = "\(Self.protocolIdentifier)\u{1F}\(normalizedFrontendApiUrl)\u{1F}\(normalizedPublishableKey)"
    fingerprint = Self.sha256(seed)
  }

  static func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }
}

struct SharedSessionIdentityEvent: Codable, Equatable {
  typealias State = ClerkIdentityState

  let id: UUID
  let originOwnerIdentifier: String
  let generation: UInt64
  let state: State
  let deviceToken: String?
  let client: Client?
  let serverDate: Date?

  func validated() throws -> Self {
    guard generation > 0 else {
      throw SharedSessionIdentityEventError.invalidGeneration
    }
    guard !originOwnerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SharedSessionIdentityEventError.missingOriginOwnerIdentifier
    }

    _ = try ClerkIdentitySnapshot(
      state: state,
      deviceToken: deviceToken,
      client: client,
      serverDate: serverDate
    ).validated()

    return self
  }

  static func nextGeneration(after baseGeneration: UInt64) throws -> UInt64 {
    let (generation, overflow) = baseGeneration.addingReportingOverflow(1)
    guard !overflow else {
      throw SharedSessionIdentityEventError.generationOverflow
    }
    return generation
  }
}

enum SharedSessionIdentityEventError: Error, Equatable {
  case invalidGeneration
  case missingOriginOwnerIdentifier
  case generationOverflow
}

struct SharedSessionOwnerSlot: Codable, Equatable {
  static let schemaVersion = 2

  let schemaVersion: Int
  let instanceFingerprint: String
  let slotOwnerIdentifier: String
  let event: SharedSessionIdentityEvent
}

struct SharedSessionReduction: Equatable {
  let winner: SharedSessionIdentityEvent?
  let maximumGeneration: UInt64
  let conflictingEventIDs: Set<UUID>
}

enum SharedSessionIdentityReducer {
  static func reduce(_ slots: [SharedSessionOwnerSlot]) -> SharedSessionReduction {
    reduce(events: slots.map(\.event))
  }

  static func reduce(events: [SharedSessionIdentityEvent]) -> SharedSessionReduction {
    let validEvents = events.compactMap { try? $0.validated() }
    let maximumGeneration = validEvents.map(\.generation).max() ?? 0

    let eventsByID = Dictionary(grouping: validEvents, by: \.id)
    let conflictingEventIDs: Set<UUID> = Set(eventsByID.compactMap { id, copies in
      guard let event = copies.first,
            !copies.dropFirst().allSatisfy({ $0 == event })
      else {
        return nil
      }
      return id
    })
    let uniqueEvents = eventsByID.values.compactMap { copies -> SharedSessionIdentityEvent? in
      guard let event = copies.first,
            copies.dropFirst().allSatisfy({ $0 == event })
      else {
        return nil
      }
      return event
    }

    return SharedSessionReduction(
      winner: uniqueEvents.max(by: eventPrecedes),
      maximumGeneration: maximumGeneration,
      conflictingEventIDs: conflictingEventIDs
    )
  }

  private static func eventPrecedes(
    _ lhs: SharedSessionIdentityEvent,
    _ rhs: SharedSessionIdentityEvent
  ) -> Bool {
    if lhs.generation != rhs.generation {
      return lhs.generation < rhs.generation
    }

    switch (lhs.serverDate, rhs.serverDate) {
    case (nil, .some):
      return true
    case (.some, nil):
      return false
    case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
      return lhsDate < rhsDate
    default:
      break
    }

    if lhs.originOwnerIdentifier != rhs.originOwnerIdentifier {
      return lhs.originOwnerIdentifier < rhs.originOwnerIdentifier
    }

    return lhs.id.uuidString < rhs.id.uuidString
  }
}
