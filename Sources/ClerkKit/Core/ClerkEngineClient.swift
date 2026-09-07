import ClerkSnapshots
import Foundation

@MainActor
package protocol ClerkEngineClient: AnyObject, Sendable {
  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue
  func invalidate()
  func dispose() async
}

extension ClerkEngineClient {
  package func invalidate() {}
  package func dispose() async {}
}

extension Clerk {
  @MainActor
  package static var engineClient: (any ClerkEngineClient)?

  @MainActor
  package static var makeEngineClient: (@MainActor (Clerk) async -> any ClerkEngineClient)?

  @MainActor private static var engineCreationTask: Task<any ClerkEngineClient, Never>?
  @MainActor private static var engineGeneration: UInt64 = 0

  @MainActor
  static func detachEngine() -> (any ClerkEngineClient)? {
    engineGeneration += 1
    engineCreationTask?.cancel()
    engineCreationTask = nil
    let previous = engineClient
    engineClient = nil
    previous?.invalidate()
    return previous
  }

  @MainActor
  static func disposeEngine() async {
    await detachEngine()?.dispose()
  }

  @MainActor
  package static func resolvedEngineClient() async -> (any ClerkEngineClient)? {
    if let clear = shared.keychainClearTask {
      do { try await clear.value } catch { return nil }
    }
    if let engineClient {
      return engineClient
    }
    guard let makeEngineClient else {
      return nil
    }
    let generation = engineGeneration
    let task: Task<any ClerkEngineClient, Never>
    if let pending = engineCreationTask {
      task = pending
    } else {
      task = Task { await makeEngineClient(shared) }
      engineCreationTask = task
    }
    let created = await task.value
    guard generation == engineGeneration else {
      await created.dispose()
      return nil
    }
    engineCreationTask = nil
    engineClient = created
    return created
  }

  @MainActor
  package static func requireEngineClient() async throws -> any ClerkEngineClient {
    guard let engine = await resolvedEngineClient() else {
      throw ClerkClientError(message: "Clerk JS engine is not available.")
    }
    return engine
  }

  @MainActor
  package static func requireEngineSignIn() throws -> SignIn {
    guard let signIn = shared.client?.signIn else {
      throw ClerkClientError(message: "Sign-in did not produce a client.")
    }
    return signIn
  }

  @MainActor
  package static func requireEngineSignUp() throws -> SignUp {
    guard let signUp = shared.client?.signUp else {
      throw ClerkClientError(message: "Sign-up did not produce a client.")
    }
    return signUp
  }
}
