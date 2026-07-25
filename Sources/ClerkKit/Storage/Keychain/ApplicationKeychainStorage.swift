import Foundation
import Security

enum AppLocalKeychainMigrationError: Error, Equatable {
  case conflictingLegacyItems
}

/// Moves records from explicitly known legacy storage locations into the
/// app's private access group. A primary record is immediately authoritative,
/// so migration does not add work to its normal read path. Shared legacy
/// sources are best-effort because their entitlement or availability must not
/// disable otherwise-usable private storage.
struct AppLocalKeychainMigratingStorage: KeychainStorage {
  private static let mutationLock = NSLock()
  private static let deletionTombstoneValue = Data([1])
  private static let deletionTombstonePrefix =
    "com.clerk.app-local-legacy-deletion.v1."

  private let primary: SystemKeychain
  private let requiredLegacySources: [SystemKeychain]
  private let optionalLegacySources: [SystemKeychain]

  init(
    primary: SystemKeychain,
    requiredLegacySources: [SystemKeychain] = [],
    optionalLegacySources: [SystemKeychain] = []
  ) {
    self.primary = primary
    self.requiredLegacySources = requiredLegacySources
    self.optionalLegacySources = optionalLegacySources
  }

  func set(_ data: Data, forKey key: String) throws {
    try Self.mutationLock.withLock {
      try primary.set(data, forKey: key)
      let removedAllLegacyItems = try removeLegacyItems(forKey: key)
      if removedAllLegacyItems, !optionalLegacySources.isEmpty {
        try primary.deleteItem(forKey: deletionTombstoneKey(for: key))
      }
    }
  }

  func data(forKey key: String) throws -> Data? {
    try Self.mutationLock.withLock {
      if let primaryData = try primary.data(forKey: key) {
        return primaryData
      }
      if !optionalLegacySources.isEmpty,
         try primary.hasItem(forKey: deletionTombstoneKey(for: key))
      {
        return nil
      }

      let legacyData = try legacyData(forKey: key)
      guard let first = legacyData.first else {
        return nil
      }
      guard legacyData.dropFirst().allSatisfy({ $0 == first }) else {
        throw AppLocalKeychainMigrationError.conflictingLegacyItems
      }

      try primary.set(first, forKey: key)
      let removedAllLegacyItems = try removeLegacyItems(forKey: key)
      if removedAllLegacyItems, !optionalLegacySources.isEmpty {
        try primary.deleteItem(forKey: deletionTombstoneKey(for: key))
      }
      return first
    }
  }

  func deleteItem(forKey key: String) throws {
    try Self.mutationLock.withLock {
      let removedAllLegacyItems = try removeLegacyItems(forKey: key)
      guard !optionalLegacySources.isEmpty else {
        try primary.deleteItem(forKey: key)
        return
      }

      let tombstoneKey = deletionTombstoneKey(for: key)
      if removedAllLegacyItems {
        try primary.deleteItem(forKey: key)
        try primary.deleteItem(forKey: tombstoneKey)
      } else {
        try primary.set(Self.deletionTombstoneValue, forKey: tombstoneKey)
        try primary.deleteItem(forKey: key)
      }
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    try data(forKey: key) != nil
  }

  private func removeLegacyItems(forKey key: String) throws -> Bool {
    var firstError: Error?
    var removedAllLegacyItems = true
    for source in requiredLegacySources {
      do {
        try source.deleteItem(forKey: key)
      } catch {
        firstError = firstError ?? error
      }
    }
    for source in optionalLegacySources {
      do {
        try source.deleteItem(forKey: key)
      } catch where Self.isOptionalSourceAvailabilityFailure(error) {
        removedAllLegacyItems = false
        continue
      } catch {
        firstError = firstError ?? error
      }
    }
    if let firstError {
      throw firstError
    }
    return removedAllLegacyItems
  }

  private func legacyData(forKey key: String) throws -> [Data] {
    var data = try requiredLegacySources.compactMap {
      try $0.data(forKey: key)
    }
    for source in optionalLegacySources {
      do {
        if let sourceData = try source.data(forKey: key) {
          data.append(sourceData)
        }
      } catch where Self.isOptionalSourceAvailabilityFailure(error) {
        continue
      }
    }
    return data
  }

  private static func isOptionalSourceAvailabilityFailure(
    _ error: any Error
  ) -> Bool {
    guard let keychainError = error as? KeychainError else {
      return false
    }
    switch keychainError {
    case .unexpectedStatus(errSecMissingEntitlement),
         .unexpectedStatus(errSecNotAvailable),
         .unexpectedStatus(errSecInteractionNotAllowed):
      return true
    case .unexpectedStatus, .invalidStringEncoding:
      return false
    }
  }

  private func deletionTombstoneKey(for key: String) -> String {
    Self.deletionTombstonePrefix
      + Data(key.utf8).base64EncodedString()
  }
}

enum ApplicationKeychainStorage {
  static func make(
    service: String,
    accessGroup: String,
    migrateLegacyUnscopedItems: Bool,
    legacyAccessGroups: [String] = []
  ) -> any KeychainStorage {
    #if os(macOS)
    let primary = SystemKeychain(
      service: service,
      accessGroup: accessGroup,
      useDataProtectionKeychain: true
    )
    guard migrateLegacyUnscopedItems else {
      return primary
    }
    return AppLocalKeychainMigratingStorage(
      primary: primary,
      // Before explicit app-local scoping, this state lived in the standard
      // macOS Keychain rather than the data-protection Keychain.
      requiredLegacySources: [SystemKeychain(service: service)]
    )
    #else
    let primary = SystemKeychain(
      service: service,
      accessGroup: accessGroup
    )
    guard migrateLegacyUnscopedItems else {
      return primary
    }
    let knownLegacyAccessGroups = legacyAccessGroups.reduce(into: [String]()) {
      if $1 != accessGroup, !$0.contains($1) {
        $0.append($1)
      }
    }
    guard !knownLegacyAccessGroups.isEmpty else {
      return primary
    }
    return AppLocalKeychainMigratingStorage(
      primary: primary,
      optionalLegacySources: knownLegacyAccessGroups.map {
        SystemKeychain(service: service, accessGroup: $0)
      }
    )
    #endif
  }
}
