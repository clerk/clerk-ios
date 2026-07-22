//
//  SharedSessionSlotTopology.swift
//  Clerk
//

import Foundation

struct SharedSessionSlotTopology: Equatable {
  struct StoreIdentity: Equatable {
    let service: String
    let accessGroup: String
    let namespace: SharedSessionNamespace
  }

  let storeIdentity: StoreIdentity
  let ownerIdentifier: String

  var instanceFingerprint: String {
    storeIdentity.namespace.fingerprint
  }

  var keychainConfig: Clerk.Options.KeychainConfig {
    Clerk.Options.KeychainConfig(
      service: storeIdentity.service,
      accessGroup: storeIdentity.accessGroup
    )
  }

  @MainActor
  init?(dependencies: any Dependencies) {
    let configuration = dependencies.configurationManager
    guard configuration.options.sharedSessionSync != nil,
          let accessGroup = configuration.options.keychainConfig.normalizedAccessGroup,
          let ownerIdentifier = dependencies.sharedSessionOwnerIdentifier,
          !ownerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }

    storeIdentity = StoreIdentity(
      service: configuration.options.keychainConfig.service,
      accessGroup: accessGroup,
      namespace: SharedSessionNamespace(
        frontendApiUrl: configuration.frontendApiUrl,
        publishableKey: configuration.publishableKey
      )
    )
    self.ownerIdentifier = ownerIdentifier
  }

  func hasSameStore(as other: Self) -> Bool {
    storeIdentity == other.storeIdentity
  }

  func hasSameOwnerSlot(as other: Self) -> Bool {
    self == other
  }

  func makeOwnerSlotStore() throws -> SharedSessionOwnerSlotStore {
    try SharedSessionOwnerSlotStore(
      keychainConfig: keychainConfig,
      namespace: storeIdentity.namespace,
      ownerIdentifier: ownerIdentifier
    )
  }
}
