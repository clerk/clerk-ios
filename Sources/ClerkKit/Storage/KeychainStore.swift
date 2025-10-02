import Foundation
import Security

struct KeychainStore {
  enum Error: Swift.Error {
    case cannotEncodeString
    case unexpectedStatus(OSStatus)
    case unexpectedResultType
  }

  struct Configuration {
    let service: String
    let accessGroup: String?
    let accessibility: Accessibility

    init(
      service: String = KeychainStore.defaultServiceIdentifier(),
      accessGroup: String? = nil,
      accessibility: Accessibility = .afterFirstUnlockThisDeviceOnly
    ) {
      let resolvedService = service.isEmpty ? KeychainStore.defaultServiceIdentifier() : service
      self.service = resolvedService
      self.accessGroup = accessGroup
      self.accessibility = accessibility
    }
  }

  enum Accessibility {
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case rawValue(String)

    fileprivate var secAttrValue: CFString {
      switch self {
      case .whenUnlocked:
        return kSecAttrAccessibleWhenUnlocked
      case .whenUnlockedThisDeviceOnly:
        return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      case .afterFirstUnlock:
        return kSecAttrAccessibleAfterFirstUnlock
      case .afterFirstUnlockThisDeviceOnly:
        return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      case .rawValue(let value):
        return value as CFString
      }
    }
  }

  private let operations: Operations

  init(configuration: Configuration = .init()) {
    self.init(operations: Self.makeSecurityOperations(configuration: configuration))
  }

  private init(operations: Operations) {
    self.operations = operations
  }

  static func inMemory() -> KeychainStore {
    KeychainStore(operations: Self.makeInMemoryOperations())
  }

  func set(_ data: Data, forKey key: String) throws {
    try operations.setData(data, key)
  }

  func set(_ string: String, forKey key: String) throws {
    guard let data = string.data(using: .utf8) else {
      throw Error.cannotEncodeString
    }
    try set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try operations.dataForKey(key)
  }

  func string(forKey key: String) throws -> String? {
    guard let data = try data(forKey: key) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  func deleteItem(forKey key: String) throws {
    try operations.deleteItem(key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try operations.hasItem(key)
  }
}

// MARK: - Private helpers
private extension KeychainStore {
  struct Operations {
    let setData: (Data, String) throws -> Void
    let dataForKey: (String) throws -> Data?
    let deleteItem: (String) throws -> Void
    let hasItem: (String) throws -> Bool
  }

  static func defaultServiceIdentifier(bundle: Bundle = .main) -> String {
    bundle.bundleIdentifier ?? "com.clerk.default-keychain"
  }

  static func makeSecurityOperations(configuration: Configuration) -> Operations {
    Operations(
      setData: { data, key in
        let baseQuery = Self.baseQuery(
          key: key,
          service: configuration.service,
          accessGroup: configuration.accessGroup
        )

        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
          return
        case errSecItemNotFound:
          var addQuery = baseQuery
          addQuery[kSecValueData as String] = data
          addQuery[kSecAttrAccessible as String] = configuration.accessibility.secAttrValue
          let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
          guard addStatus == errSecSuccess else {
            throw Error.unexpectedStatus(addStatus)
          }
        default:
          throw Error.unexpectedStatus(status)
        }
      },
      dataForKey: { key in
        var query = Self.baseQuery(
          key: key,
          service: configuration.service,
          accessGroup: configuration.accessGroup
        )
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
          guard let data = item as? Data else {
            throw Error.unexpectedResultType
          }
          return data
        case errSecItemNotFound:
          return nil
        default:
          throw Error.unexpectedStatus(status)
        }
      },
      deleteItem: { key in
        let status = SecItemDelete(
          Self.baseQuery(
            key: key,
            service: configuration.service,
            accessGroup: configuration.accessGroup
          ) as CFDictionary
        )
        switch status {
        case errSecSuccess, errSecItemNotFound:
          return
        default:
          throw Error.unexpectedStatus(status)
        }
      },
      hasItem: { key in
        var query = Self.baseQuery(
          key: key,
          service: configuration.service,
          accessGroup: configuration.accessGroup
        )
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
          return true
        case errSecItemNotFound:
          return false
        default:
          throw Error.unexpectedStatus(status)
        }
      }
    )
  }

  static func makeInMemoryOperations() -> Operations {
    let queue = DispatchQueue(label: "KeychainStore.inMemoryQueue")
    var storage: [String: Data] = [:]

    return Operations(
      setData: { data, key in
        queue.sync {
          storage[key] = data
        }
      },
      dataForKey: { key in
        queue.sync {
          storage[key]
        }
      },
      deleteItem: { key in
        queue.sync {
          storage.removeValue(forKey: key)
        }
      },
      hasItem: { key in
        queue.sync {
          storage[key] != nil
        }
      }
    )
  }

  static func baseQuery(
    key: String,
    service: String,
    accessGroup: String?
  ) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]

    if let accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }

    return query
  }
}
