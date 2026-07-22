//
//  SharedSessionOwnerSlotStore.swift
//  Clerk
//

import Foundation
import Security

protocol SharedSessionSlotStoring: Sendable {
  func loadOwnSlot() throws -> SharedSessionOwnerSlot?
  func loadAllSlots() throws -> [SharedSessionOwnerSlot]
  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws
  func deleteOwnSlot() throws
}

enum SharedSessionOwnerSlotStoreError: Error, Equatable {
  case missingAccessGroup
  case missingOwnerIdentifier
  case invalidOwnSlot
  case ownerAccountMismatch
  case futureSchemaVersion(Int)
}

struct SharedSessionOwnerSlotStore: SharedSessionSlotStoring {
  private struct SchemaVersionHeader: Decodable {
    let schemaVersion: Int
  }

  private struct SlotHeader: Decodable {
    let schemaVersion: Int
    let instanceFingerprint: String
    let slotOwnerIdentifier: String
  }

  private let service: String
  private let accessGroup: String
  private let instanceFingerprint: String
  private let ownerIdentifier: String
  private let ownerAccount: String
  private let useDataProtectionKeychain: Bool
  private let secItemClient: SystemKeychain.SecItemClient
  private let diagnostics: @Sendable (String) -> Void

  init(
    keychainConfig: Clerk.Options.KeychainConfig,
    namespace: SharedSessionNamespace,
    ownerIdentifier: String,
    secItemClient: SystemKeychain.SecItemClient = .live,
    diagnostics: @escaping @Sendable (String) -> Void = {
      ClerkLogger.debug($0)
    }
  ) throws {
    guard let accessGroup = keychainConfig.normalizedAccessGroup else {
      throw SharedSessionOwnerSlotStoreError.missingAccessGroup
    }
    guard !ownerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SharedSessionOwnerSlotStoreError.missingOwnerIdentifier
    }

    self.init(
      service: Self.service(
        configuredService: keychainConfig.service,
        instanceFingerprint: namespace.fingerprint
      ),
      accessGroup: accessGroup,
      instanceFingerprint: namespace.fingerprint,
      ownerIdentifier: ownerIdentifier,
      ownerAccount: Self.account(
        instanceFingerprint: namespace.fingerprint,
        ownerIdentifier: ownerIdentifier
      ),
      secItemClient: secItemClient,
      diagnostics: diagnostics
    )
  }

  init(
    clearRecoveryIntent intent: SharedSessionOwnerSlotClearRecovery.Intent,
    secItemClient: SystemKeychain.SecItemClient = .live,
    diagnostics: @escaping @Sendable (String) -> Void = {
      ClerkLogger.debug($0)
    }
  ) throws {
    let intent = try intent.validated()
    self.init(
      service: intent.slotService,
      accessGroup: intent.slotAccessGroup,
      instanceFingerprint: intent.instanceFingerprint,
      ownerIdentifier: intent.ownerIdentifier,
      ownerAccount: intent.slotAccount,
      secItemClient: secItemClient,
      diagnostics: diagnostics
    )
  }

  private init(
    service: String,
    accessGroup: String,
    instanceFingerprint: String,
    ownerIdentifier: String,
    ownerAccount: String,
    secItemClient: SystemKeychain.SecItemClient,
    diagnostics: @escaping @Sendable (String) -> Void
  ) {
    self.service = service
    self.accessGroup = accessGroup
    self.instanceFingerprint = instanceFingerprint
    self.ownerIdentifier = ownerIdentifier
    self.ownerAccount = ownerAccount
    #if os(macOS)
    useDataProtectionKeychain = true
    #else
    useDataProtectionKeychain = false
    #endif
    self.secItemClient = secItemClient
    self.diagnostics = diagnostics
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    guard let data = try loadData(account: ownerAccount) else {
      return nil
    }
    return decodeCompatibleSlot(data: data, account: ownerAccount, requireOwnOwner: true)
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    var query = baseQuery()
    query[kSecReturnAttributes as String] = true
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitAll

    var result: CFTypeRef?
    let status = secItemClient.copyMatching(query as CFDictionary, &result)
    switch status {
    case errSecItemNotFound:
      return []
    case errSecSuccess:
      break
    default:
      throw KeychainError.unexpectedStatus(status)
    }

    let items: [[String: Any]]
    if let result = result as? [[String: Any]] {
      items = result
    } else if let result = result as? [String: Any] {
      items = [result]
    } else {
      return []
    }

    return items.compactMap { item in
      guard let account = item[kSecAttrAccount as String] as? String,
            let data = item[kSecValueData as String] as? Data
      else {
        return nil
      }
      return decodeCompatibleSlot(data: data, account: account, requireOwnOwner: false)
    }
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    guard slot.schemaVersion == SharedSessionOwnerSlot.schemaVersion,
          slot.instanceFingerprint == instanceFingerprint,
          slot.slotOwnerIdentifier == ownerIdentifier,
          (try? slot.event.validated()) != nil
    else {
      throw SharedSessionOwnerSlotStoreError.invalidOwnSlot
    }

    let existingData = try loadData(account: ownerAccount)
    if let existingData {
      try validateExistingOwnSlot(existingData)
    }

    let data = try JSONEncoder.clerkEncoder.encode(slot)
    try writeOwnSlot(data, itemExists: existingData != nil)
  }

  func deleteOwnSlot() throws {
    if let data = try loadData(account: ownerAccount),
       let header = try? JSONDecoder.clerkDecoder.decode(SchemaVersionHeader.self, from: data),
       header.schemaVersion > SharedSessionOwnerSlot.schemaVersion
    {
      throw SharedSessionOwnerSlotStoreError.futureSchemaVersion(
        header.schemaVersion
      )
    }

    let status = secItemClient.delete(query(account: ownerAccount) as CFDictionary)
    switch status {
    case errSecSuccess, errSecItemNotFound:
      return
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  static func service(configuredService: String, instanceFingerprint: String) -> String {
    "\(configuredService).\(SharedSessionNamespace.protocolIdentifier).\(instanceFingerprint)"
  }

  static func account(instanceFingerprint: String, ownerIdentifier: String) -> String {
    let seed = "\(SharedSessionNamespace.protocolIdentifier)\u{1F}\(instanceFingerprint)\u{1F}\(ownerIdentifier)"
    return "owner.\(SharedSessionNamespace.sha256(seed))"
  }

  private func decodeCompatibleSlot(
    data: Data,
    account: String,
    requireOwnOwner: Bool
  ) -> SharedSessionOwnerSlot? {
    guard let versionHeader = try? JSONDecoder.clerkDecoder.decode(
      SchemaVersionHeader.self,
      from: data
    ) else {
      diagnostics("Ignoring a malformed shared-session owner slot.")
      return nil
    }
    guard versionHeader.schemaVersion == SharedSessionOwnerSlot.schemaVersion else {
      if versionHeader.schemaVersion > SharedSessionOwnerSlot.schemaVersion {
        diagnostics("Ignoring a shared-session owner slot from a future schema version.")
      }
      return nil
    }
    guard let header = try? JSONDecoder.clerkDecoder.decode(SlotHeader.self, from: data) else {
      diagnostics("Ignoring a malformed shared-session owner slot.")
      return nil
    }
    guard header.instanceFingerprint == instanceFingerprint else {
      return nil
    }
    guard account == Self.account(
      instanceFingerprint: instanceFingerprint,
      ownerIdentifier: header.slotOwnerIdentifier
    ) else {
      diagnostics("Ignoring a shared-session owner slot whose account does not match its owner.")
      return nil
    }
    guard !requireOwnOwner || header.slotOwnerIdentifier == ownerIdentifier,
          let slot = try? JSONDecoder.clerkDecoder.decode(SharedSessionOwnerSlot.self, from: data),
          (try? slot.event.validated()) != nil
    else {
      return nil
    }
    return slot
  }

  private func loadData(account: String) throws -> Data? {
    var query = query(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = secItemClient.copyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      return result as? Data
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  private func query(account: String) -> [String: Any] {
    var query = baseQuery()
    query[kSecAttrAccount as String] = account
    return query
  }

  private func baseQuery() -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccessGroup as String: accessGroup,
    ]
    if useDataProtectionKeychain {
      query[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue
    }
    return query
  }
}

extension SharedSessionOwnerSlotStore {
  private func validateExistingOwnSlot(_ data: Data) throws {
    if let versionHeader = try? JSONDecoder.clerkDecoder.decode(
      SchemaVersionHeader.self,
      from: data
    ) {
      guard versionHeader.schemaVersion <= SharedSessionOwnerSlot.schemaVersion else {
        throw SharedSessionOwnerSlotStoreError.futureSchemaVersion(versionHeader.schemaVersion)
      }
    }

    if let header = try? JSONDecoder.clerkDecoder.decode(SlotHeader.self, from: data) {
      guard header.slotOwnerIdentifier == ownerIdentifier,
            header.instanceFingerprint == instanceFingerprint
      else {
        throw SharedSessionOwnerSlotStoreError.ownerAccountMismatch
      }
    }
  }

  private func writeOwnSlot(_ data: Data, itemExists: Bool) throws {
    if itemExists {
      let updateStatus = updateOwnSlot(with: data)
      switch updateStatus {
      case errSecSuccess:
        return
      case errSecItemNotFound:
        break
      default:
        throw KeychainError.unexpectedStatus(updateStatus)
      }
    }

    var addQuery = query(account: ownerAccount)
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    addQuery[kSecValueData as String] = data

    let status = secItemClient.add(addQuery as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return
    case errSecDuplicateItem:
      guard let currentData = try loadData(account: ownerAccount) else {
        throw KeychainError.unexpectedStatus(errSecItemNotFound)
      }
      try validateExistingOwnSlot(currentData)
      let updateStatus = updateOwnSlot(with: data)
      guard updateStatus == errSecSuccess else {
        throw KeychainError.unexpectedStatus(updateStatus)
      }
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  private func updateOwnSlot(with data: Data) -> OSStatus {
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    return secItemClient.update(
      query(account: ownerAccount) as CFDictionary,
      attributes as CFDictionary
    )
  }
}
