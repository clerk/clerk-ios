@testable import ClerkKit
import Foundation
import Security
import Testing

struct ApplicationKeychainStorageTests {
  private let service = "com.clerk.tests.app-local"
  private let account = "identity"
  private let appLocalGroup = "TEAMID.com.example.app"
  private let sharedGroup = "TEAMID.com.example.shared"

  @Test
  func explicitlyScopedOperationsDoNotTouchSharedItem() throws {
    let store = KeychainTopologyStore(defaultAccessGroup: sharedGroup)
    let sharedData = Data("shared".utf8)
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: sharedData
    )
    let appLocal = SystemKeychain(
      service: service,
      accessGroup: appLocalGroup,
      secItemClient: store.client
    )

    #expect(try appLocal.data(forKey: account) == nil)
    try appLocal.set(Data("private".utf8), forKey: account)
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("private".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == sharedData)

    try appLocal.deleteItem(forKey: account)

    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == nil)
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == sharedData)
  }

  @Test
  func legacySharedCopyMovesToAppLocalGroup() throws {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("legacy".utf8)
    )

    #expect(try storage.data(forKey: account) == Data("legacy".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("legacy".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == nil)
  }

  @Test
  func appLocalCopyIsAuthoritativeWithoutScanningLegacyGroups() throws {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: appLocalGroup,
      data: Data("current".utf8)
    )
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("stale".utf8)
    )
    store.forceCopyMatchingStatus(
      errSecMissingEntitlement,
      accessGroup: sharedGroup
    )

    #expect(try storage.data(forKey: account) == Data("current".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == Data("stale".utf8))
    #expect(store.copyMatchingAccessGroups == [appLocalGroup])
  }

  @Test
  func unrelatedGroupIsNeverReadOrDeletedDuringMigration() throws {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("first".utf8)
    )
    let unrelatedGroup = "TEAMID.com.example.other"
    store.seed(
      service: service,
      account: account,
      accessGroup: unrelatedGroup,
      data: Data("second".utf8)
    )

    #expect(try storage.data(forKey: account) == Data("first".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("first".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == nil)
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: unrelatedGroup
    ) == Data("second".utf8))
    #expect(!store.copyMatchingAccessGroups.contains(unrelatedGroup))
  }

  @Test
  func conflictingExplicitLegacySourcesFailClosed() throws {
    let secondLegacyGroup = "TEAMID.com.example.previous-shared"
    let store = KeychainTopologyStore(defaultAccessGroup: sharedGroup)
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("first".utf8)
    )
    store.seed(
      service: service,
      account: account,
      accessGroup: secondLegacyGroup,
      data: Data("second".utf8)
    )
    let storage = AppLocalKeychainMigratingStorage(
      primary: SystemKeychain(
        service: service,
        accessGroup: appLocalGroup,
        secItemClient: store.client
      ),
      optionalLegacySources: [
        SystemKeychain(
          service: service,
          accessGroup: sharedGroup,
          secItemClient: store.client
        ),
        SystemKeychain(
          service: service,
          accessGroup: secondLegacyGroup,
          secItemClient: store.client
        ),
      ]
    )

    #expect(throws: AppLocalKeychainMigrationError.conflictingLegacyItems) {
      try storage.data(forKey: account)
    }
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == nil)
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == Data("first".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: secondLegacyGroup
    ) == Data("second".utf8))
  }

  @Test
  func conflictingLegacyItemsAreClassifiedAsIncompatibleStoredData() {
    let failure = PersistenceFailureKind.classify(
      AppLocalKeychainMigrationError.conflictingLegacyItems
    )

    #expect(failure == .incompatibleStoredData)
    #expect(!failure.permitsVolatileIdentityFallback)
  }

  @Test(
    arguments: [
      errSecMissingEntitlement,
      errSecNotAvailable,
      errSecInteractionNotAllowed,
    ]
  )
  func unavailableOptionalLegacySourceDoesNotDisablePrivateStorage(
    _ status: OSStatus
  ) throws {
    let (store, storage) = makeMigratingStorage()
    store.forceCopyMatchingStatus(status, accessGroup: sharedGroup)
    store.forceDeleteStatus(status, accessGroup: sharedGroup)

    #expect(try storage.data(forKey: account) == nil)

    try storage.set(Data("current".utf8), forKey: account)

    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("current".utf8))
  }

  @Test
  func unavailableOptionalLegacyCleanupDoesNotFailPrivateDelete() throws {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: appLocalGroup,
      data: Data("current".utf8)
    )
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("stale".utf8)
    )
    store.forceDeleteStatus(
      errSecMissingEntitlement,
      accessGroup: sharedGroup
    )

    try storage.deleteItem(forKey: account)

    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == nil)

    store.clearForcedStatuses(accessGroup: sharedGroup)
    let recreatedStorage = makeMigratingStorage(in: store)

    #expect(try recreatedStorage.data(forKey: account) == nil)
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == Data("stale".utf8))
  }

  @Test
  func unexpectedOptionalLegacyReadErrorRemainsStrict() {
    let (store, storage) = makeMigratingStorage()
    store.forceCopyMatchingStatus(errSecAuthFailed, accessGroup: sharedGroup)

    #expect(throws: KeychainError.self) {
      try storage.data(forKey: account)
    }
  }

  @Test
  func unexpectedOptionalLegacyCleanupErrorDoesNotFailCommittedWrite() throws {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("stale".utf8)
    )
    store.forceDeleteStatus(errSecAuthFailed, accessGroup: sharedGroup)

    try storage.set(Data("current".utf8), forKey: account)

    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("current".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == Data("stale".utf8))
    #expect(try storage.data(forKey: account) == Data("current".utf8))
  }

  @Test
  func migrationReadReturnsCommittedValueWhenLegacyCleanupFails() throws {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("legacy".utf8)
    )
    store.forceDeleteStatus(errSecAuthFailed, accessGroup: sharedGroup)

    #expect(try storage.data(forKey: account) == Data("legacy".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("legacy".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == Data("legacy".utf8))
  }

  @Test
  func unexpectedTombstoneCleanupErrorDoesNotFailCommittedWrite() throws {
    let (store, storage) = makeMigratingStorage()
    store.forceDeleteStatus(errSecAuthFailed, accessGroup: appLocalGroup)

    try storage.set(Data("current".utf8), forKey: account)

    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("current".utf8))
    #expect(try storage.data(forKey: account) == Data("current".utf8))
  }

  @Test
  func unexpectedRequiredLegacyCleanupErrorDoesNotFailCommittedWrite() throws {
    let requiredLegacyGroup = "TEAMID.com.example.required-legacy"
    let store = KeychainTopologyStore(defaultAccessGroup: requiredLegacyGroup)
    store.seed(
      service: service,
      account: account,
      accessGroup: requiredLegacyGroup,
      data: Data("stale".utf8)
    )
    store.forceDeleteStatus(
      errSecAuthFailed,
      accessGroup: requiredLegacyGroup
    )
    let storage = AppLocalKeychainMigratingStorage(
      primary: SystemKeychain(
        service: service,
        accessGroup: appLocalGroup,
        secItemClient: store.client
      ),
      requiredLegacySources: [
        SystemKeychain(
          service: service,
          accessGroup: requiredLegacyGroup,
          secItemClient: store.client
        ),
      ]
    )

    try storage.set(Data("current".utf8), forKey: account)

    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("current".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: requiredLegacyGroup
    ) == Data("stale".utf8))
    #expect(try storage.data(forKey: account) == Data("current".utf8))
  }

  @MainActor
  @Test
  func committedIdentityWriteIsAppliedToMemoryWhenLegacyCleanupFails() async throws {
    let clerk = Clerk()
    let (topologyStore, storage) = makeMigratingStorage()
    let identityStore = SharedSessionLocalIdentityStore(keychain: storage)
    var previousClient = Client.mock
    previousClient.id = "previous-client"
    let previousIdentity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "previous-token",
      client: previousClient,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try identityStore.save(previousIdentity)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: storage,
      atomicIdentityStore: identityStore
    )
    clerk.hydrateIdentityIfNeeded(previousIdentity)
    topologyStore.seed(
      service: service,
      account: SharedSessionLocalIdentityStore.storageKey,
      accessGroup: sharedGroup,
      data: Data("stale".utf8)
    )
    topologyStore.forceDeleteStatus(
      errSecAuthFailed,
      accessGroup: sharedGroup
    )
    var replacementClient = Client.mock
    replacementClient.id = "replacement-client"
    let replacementIdentity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "replacement-token",
      client: replacementClient,
      serverDate: Date(timeIntervalSince1970: 200)
    )

    let task = try #require(
      try clerk.identityController.submitExternalTransition {
        ClerkIdentityController.ExternalTransition(
          identity: replacementIdentity
        )
      }
    )
    try await task.value

    #expect(clerk.client?.id == replacementClient.id)
    #expect(
      clerk.identityController.currentDeviceToken
        == replacementIdentity.deviceToken
    )
    let persistedIdentity = try #require(try identityStore.load())
    #expect(persistedIdentity.deviceToken == replacementIdentity.deviceToken)
    #expect(persistedIdentity.client?.id == replacementClient.id)
    #expect(persistedIdentity.serverDate == replacementIdentity.serverDate)
    let recreatedIdentityStore = SharedSessionLocalIdentityStore(
      keychain: makeMigratingStorage(in: topologyStore)
    )
    let recreatedIdentity = try #require(try recreatedIdentityStore.load())
    #expect(recreatedIdentity.deviceToken == replacementIdentity.deviceToken)
    #expect(recreatedIdentity.client?.id == replacementClient.id)
    #expect(recreatedIdentity.serverDate == replacementIdentity.serverDate)
  }

  @Test
  func unexpectedOptionalLegacyDeleteErrorPreservesPrivateData() {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: appLocalGroup,
      data: Data("current".utf8)
    )
    store.forceDeleteStatus(errSecAuthFailed, accessGroup: sharedGroup)

    #expect(throws: KeychainError.self) {
      try storage.deleteItem(forKey: account)
    }
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("current".utf8))
  }

  @Test
  func privatePrimaryErrorsRemainStrict() {
    let (store, storage) = makeMigratingStorage()
    store.forceCopyMatchingStatus(
      errSecInteractionNotAllowed,
      accessGroup: appLocalGroup
    )
    store.forceCopyMatchingStatus(
      errSecMissingEntitlement,
      accessGroup: sharedGroup
    )

    #expect(throws: KeychainError.self) {
      try storage.data(forKey: account)
    }
  }

  @Test
  func newWriteUsesAppLocalGroupAndRemovesLegacyCopy() throws {
    let (store, storage) = makeMigratingStorage()
    store.seed(
      service: service,
      account: account,
      accessGroup: sharedGroup,
      data: Data("legacy".utf8)
    )

    try storage.set(Data("current".utf8), forKey: account)

    #expect(store.data(
      service: service,
      account: account,
      accessGroup: appLocalGroup
    ) == Data("current".utf8))
    #expect(store.data(
      service: service,
      account: account,
      accessGroup: sharedGroup
    ) == nil)
  }

  private func makeMigratingStorage() -> (
    KeychainTopologyStore,
    AppLocalKeychainMigratingStorage
  ) {
    let store = KeychainTopologyStore(defaultAccessGroup: sharedGroup)
    return (store, makeMigratingStorage(in: store))
  }

  private func makeMigratingStorage(
    in store: KeychainTopologyStore
  ) -> AppLocalKeychainMigratingStorage {
    AppLocalKeychainMigratingStorage(
      primary: SystemKeychain(
        service: service,
        accessGroup: appLocalGroup,
        secItemClient: store.client
      ),
      optionalLegacySources: [SystemKeychain(
        service: service,
        accessGroup: sharedGroup,
        secItemClient: store.client
      )]
    )
  }
}

private final class KeychainTopologyStore: @unchecked Sendable {
  private struct Item {
    let service: String
    let account: String
    let accessGroup: String
    var data: Data
    let usesDataProtectionKeychain: Bool
  }

  private let lock = NSLock()
  private let defaultAccessGroup: String
  private var items: [Item] = []
  private var queriedAccessGroups: [String?] = []
  private var copyMatchingStatuses: [String: OSStatus] = [:]
  private var deleteStatuses: [String: OSStatus] = [:]

  init(defaultAccessGroup: String) {
    self.defaultAccessGroup = defaultAccessGroup
  }

  var client: SystemKeychain.SecItemClient {
    .init(
      add: { query, _ in
        self.add(query)
      },
      update: { query, attributes in
        self.update(query, attributes: attributes)
      },
      copyMatching: { query, result in
        self.copyMatching(query, result: result)
      },
      delete: { query in
        self.delete(query)
      }
    )
  }

  func seed(
    service: String,
    account: String,
    accessGroup: String,
    data: Data,
    usesDataProtectionKeychain: Bool = false
  ) {
    lock.withLock {
      items.append(
        Item(
          service: service,
          account: account,
          accessGroup: accessGroup,
          data: data,
          usesDataProtectionKeychain: usesDataProtectionKeychain
        )
      )
    }
  }

  func data(
    service: String,
    account: String,
    accessGroup: String,
    usesDataProtectionKeychain: Bool = false
  ) -> Data? {
    lock.withLock {
      items.first {
        $0.service == service
          && $0.account == account
          && $0.accessGroup == accessGroup
          && $0.usesDataProtectionKeychain == usesDataProtectionKeychain
      }?.data
    }
  }

  var copyMatchingAccessGroups: [String?] {
    lock.withLock {
      queriedAccessGroups
    }
  }

  func forceCopyMatchingStatus(
    _ status: OSStatus,
    accessGroup: String
  ) {
    lock.withLock {
      copyMatchingStatuses[accessGroup] = status
    }
  }

  func forceDeleteStatus(
    _ status: OSStatus,
    accessGroup: String
  ) {
    lock.withLock {
      deleteStatuses[accessGroup] = status
    }
  }

  func clearForcedStatuses(accessGroup: String) {
    lock.withLock {
      copyMatchingStatuses[accessGroup] = nil
      deleteStatuses[accessGroup] = nil
    }
  }

  private func add(
    _ query: CFDictionary
  ) -> OSStatus {
    lock.withLock {
      let query = dictionary(query)
      guard let service = query[kSecAttrService as String] as? String,
            let account = query[kSecAttrAccount as String] as? String,
            let data = query[kSecValueData as String] as? Data
      else {
        return errSecParam
      }
      let accessGroup = query[kSecAttrAccessGroup as String] as? String
        ?? defaultAccessGroup
      let usesDataProtectionKeychain = dataProtectionFlag(in: query)
      guard !items.contains(where: {
        $0.service == service
          && $0.account == account
          && $0.accessGroup == accessGroup
          && $0.usesDataProtectionKeychain == usesDataProtectionKeychain
      }) else {
        return errSecDuplicateItem
      }
      items.append(
        Item(
          service: service,
          account: account,
          accessGroup: accessGroup,
          data: data,
          usesDataProtectionKeychain: usesDataProtectionKeychain
        )
      )
      return errSecSuccess
    }
  }

  private func update(
    _ query: CFDictionary,
    attributes: CFDictionary
  ) -> OSStatus {
    lock.withLock {
      let query = dictionary(query)
      let attributes = dictionary(attributes)
      let indices = matchingIndices(query)
      guard !indices.isEmpty else {
        return errSecItemNotFound
      }
      guard let data = attributes[kSecValueData as String] as? Data else {
        return errSecParam
      }
      for index in indices {
        items[index].data = data
      }
      return errSecSuccess
    }
  }

  private func copyMatching(
    _ query: CFDictionary,
    result: UnsafeMutablePointer<CFTypeRef?>?
  ) -> OSStatus {
    lock.withLock {
      let query = dictionary(query)
      queriedAccessGroups.append(
        query[kSecAttrAccessGroup as String] as? String
      )
      if let accessGroup = query[kSecAttrAccessGroup as String] as? String,
         let status = copyMatchingStatuses[accessGroup]
      {
        return status
      }
      let matches = matchingIndices(query).map { items[$0] }
      guard !matches.isEmpty else {
        return errSecItemNotFound
      }

      if query[kSecReturnAttributes as String] as? Bool == true {
        let dictionaries = matches.map { item -> [String: Any] in
          var dictionary: [String: Any] = [
            kSecAttrService as String: item.service,
            kSecAttrAccount as String: item.account,
            kSecAttrAccessGroup as String: item.accessGroup,
          ]
          if query[kSecReturnData as String] as? Bool == true {
            dictionary[kSecValueData as String] = item.data
          }
          return dictionary
        }
        if query[kSecMatchLimit as String] as? String
          == kSecMatchLimitAll as String
        {
          result?.pointee = dictionaries as CFArray
        } else {
          result?.pointee = dictionaries[0] as CFDictionary
        }
      } else if query[kSecReturnData as String] as? Bool == true {
        result?.pointee = matches[0].data as CFData
      }
      return errSecSuccess
    }
  }

  private func delete(
    _ query: CFDictionary
  ) -> OSStatus {
    lock.withLock {
      let query = dictionary(query)
      if let accessGroup = query[kSecAttrAccessGroup as String] as? String,
         let status = deleteStatuses[accessGroup]
      {
        return status
      }
      let indices = matchingIndices(query)
      guard !indices.isEmpty else {
        return errSecItemNotFound
      }
      for index in indices.reversed() {
        items.remove(at: index)
      }
      return errSecSuccess
    }
  }

  private func matchingIndices(_ query: [String: Any]) -> [Int] {
    let service = query[kSecAttrService as String] as? String
    let account = query[kSecAttrAccount as String] as? String
    let accessGroup = query[kSecAttrAccessGroup as String] as? String
    let usesDataProtectionKeychain = dataProtectionFlag(in: query)

    return items.indices.filter { index in
      let item = items[index]
      return (service == nil || item.service == service)
        && (account == nil || item.account == account)
        && (accessGroup == nil || item.accessGroup == accessGroup)
        && item.usesDataProtectionKeychain == usesDataProtectionKeychain
    }
  }

  private func dictionary(_ value: CFDictionary) -> [String: Any] {
    value as NSDictionary as? [String: Any] ?? [:]
  }

  private func dataProtectionFlag(in query: [String: Any]) -> Bool {
    query[kSecUseDataProtectionKeychain as String] as? Bool == true
  }
}
