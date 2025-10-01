import Foundation

/// Persists and restores Clerk state backed by the shared keychain store.
final class PersistedStateStore {
  private enum Key {
    static let client = "cachedClient"
    static let environment = "cachedEnvironment"
  }

  private let keychain: KeychainStore

  init(keychain: KeychainStore) {
    self.keychain = keychain
  }

  func store(client: Client) {
    do {
      let clientData = try JSONEncoder.clerkEncoder.encode(client)
      try keychain.set(clientData, forKey: Key.client)
    } catch {
      Logger.log(level: .error, message: "Failed to persist cached client", error: error)
    }
  }

  func restoreClient() -> Client? {
    do {
      guard let clientData = try keychain.data(forKey: Key.client) else {
        return nil
      }
      let decoder = JSONDecoder.clerkDecoder
      return try decoder.decode(Client.self, from: clientData)
    } catch {
      Logger.log(level: .error, message: "Failed to restore cached client", error: error)
      return nil
    }
  }

  func clearClient() {
    do {
      try keychain.deleteItem(forKey: Key.client)
    } catch {
      Logger.log(level: .error, message: "Failed to clear cached client", error: error)
    }
  }

  func store(environment: Clerk.Environment) {
    do {
      let encoder = JSONEncoder.clerkEncoder
      let environmentData = try encoder.encode(environment)
      try keychain.set(environmentData, forKey: Key.environment)
    } catch {
      Logger.log(level: .error, message: "Failed to persist cached environment", error: error)
    }
  }

  func restoreEnvironment() -> Clerk.Environment? {
    do {
      guard let environmentData = try keychain.data(forKey: Key.environment) else {
        return nil
      }
      let decoder = JSONDecoder.clerkDecoder
      return try decoder.decode(Clerk.Environment.self, from: environmentData)
    } catch {
      Logger.log(level: .error, message: "Failed to restore cached environment", error: error)
      return nil
    }
  }
}
