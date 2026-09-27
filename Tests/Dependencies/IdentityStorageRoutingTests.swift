@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Security
import Testing

@MainActor
struct IdentityStorageRoutingTests {
  @Test(arguments: [false, true])
  func leavingSharingKeepsLocalUpdatesAndClearsOutOfTheGroup(sharedGroupIsDefault: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    func app(_ owner: String, sharing: Bool) throws -> Clerk {
      let clerk = Clerk()
      let client = database.client(owner: owner, sharedGroupIsDefault: sharedGroupIsDefault)
      clerk.dependencies = try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(telemetryEnabled: false, keychainConfig: .init(service: "common-service", accessGroup: "shared"),
                       sharedSessionSync: sharing ? .enabled : nil),
        runtimeScope: clerk.runtimeScope, migratesPersistentStateOverride: true,
        keychainFactory: { SystemKeychain(service: $0, accessGroup: $1, secItemClient: client) },
        ownerIdentifierProvider: { owner }
      )
      clerk.identityController.hydrate()
      return clerk
    }

    let first = try app("app.a", sharing: true)
    try first.seedIdentity(deviceToken: "shared-token", client: .mock)
    let sibling = try app("app.b", sharing: true)
    let sharedRecord = try #require(try sibling.dependencies.identityStore.load())
    let local = try app("app.a", sharing: false)
    #expect(local.deviceToken == "shared-token")
    try local.seedIdentity(deviceToken: "local-token", client: .mock)
    #expect(try sibling.dependencies.identityStore.load() == sharedRecord)
    try local.clearKeychainItems()
    #expect(try sibling.dependencies.identityStore.load() == sharedRecord)
    #expect(try app("app.a", sharing: false).deviceToken == nil)
    #expect(try app("app.b", sharing: true).deviceToken == "shared-token")
    #expect(try app("app.a", sharing: true).deviceToken == "shared-token")
  }

  @Test
  func unscopedQueriesReallyDoFindAndUpdateAnAccessibleSharedItem() throws {
    let database = AccessGroupKeychainDatabase()
    let client = database.client(owner: "app.a", sharedGroupIsDefault: false)
    let shared = SystemKeychain(service: "common", accessGroup: "shared", secItemClient: client)
    let unscoped = SystemKeychain(service: "common", secItemClient: client)
    let revision = UUID()
    #expect(try shared.compareAndSwap(Data("old".utf8), forKey: "identity", expectedRevision: nil, newRevision: revision))
    #expect(try unscoped.data(forKey: "identity") == Data("old".utf8))
    #expect(try unscoped.compareAndSwap(Data("new".utf8), forKey: "identity", expectedRevision: revision, newRevision: UUID()))
    #expect(try shared.data(forKey: "identity") == Data("new".utf8))
    try unscoped.deleteItem(forKey: "identity")
    #expect(try shared.data(forKey: "identity") == nil)
  }
}

/// Models Apple's access-group matching while exercising the actual SystemKeychain
/// query builder. A nil group searches every accessible group; adds use the first one.
private final class AccessGroupKeychainDatabase: @unchecked Sendable {
  private let lock = NSLock()
  private var items: [[String: Any]] = []

  func client(owner: String, sharedGroupIsDefault: Bool) -> SystemKeychain.SecItemClient {
    let groups = sharedGroupIsDefault ? ["shared", owner] : [owner, "shared"]
    return .init(
      add: { query, _ in
        self.lock.withLock {
          var item = query as! [String: Any]
          item[kSecAttrAccessGroup as String] = item[kSecAttrAccessGroup as String] ?? groups[0]
          guard groups.contains(item[kSecAttrAccessGroup as String] as! String) else { return errSecMissingEntitlement }
          let identityKeys = [kSecClass, kSecAttrService, kSecAttrAccount, kSecAttrAccessGroup].map { $0 as String }
          let identity = item.filter { identityKeys.contains($0.key) }
          guard !self.items.contains(where: { self.matches($0, query: identity, groups: groups) }) else { return errSecDuplicateItem }
          self.items.append(item)
          return errSecSuccess
        }
      },
      update: { query, attributes in
        self.lock.withLock {
          let indices = self.items.indices.filter { self.matches(self.items[$0], query: query as! [String: Any], groups: groups) }
          guard !indices.isEmpty else { return errSecItemNotFound }
          for index in indices {
            self.items[index].merge(attributes as! [String: Any]) { _, new in new }
          }
          return errSecSuccess
        }
      },
      copyMatching: { query, result in
        self.lock.withLock {
          let query = query as! [String: Any]
          let matches = self.items.filter { self.matches($0, query: query, groups: groups) }
          guard let first = matches.first else { return errSecItemNotFound }
          if query[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String {
            result?.pointee = matches as CFArray
          } else if query[kSecReturnData as String] as? Bool == true {
            result?.pointee = first[kSecValueData as String] as CFTypeRef?
          }
          return errSecSuccess
        }
      },
      delete: { query in
        self.lock.withLock {
          let count = self.items.count
          self.items.removeAll { self.matches($0, query: query as! [String: Any], groups: groups) }
          return self.items.count == count ? errSecItemNotFound : errSecSuccess
        }
      }
    )
  }

  private func matches(_ item: [String: Any], query: [String: Any], groups: [String]) -> Bool {
    guard let group = item[kSecAttrAccessGroup as String] as? String, groups.contains(group) else { return false }
    return [kSecClass, kSecAttrService, kSecAttrAccount, kSecAttrAccessGroup, kSecAttrGeneric].allSatisfy {
      let key = $0 as String
      guard let value = query[key] as? NSObject else { return true }
      return value.isEqual(item[key])
    }
  }
}
