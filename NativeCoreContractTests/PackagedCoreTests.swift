@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Testing

@MainActor @Suite(.serialized) struct PackagedCoreTests {
  private func connect(_ capabilities: any NativeCapabilities) async throws -> Clerk {
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    return try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: capabilities)
  }

  private func postActive(_ active: Bool) async throws {
    #if canImport(UIKit)
    let notification = active ? UIApplication.didBecomeActiveNotification : UIApplication.willResignActiveNotification
    #elseif canImport(AppKit)
    let notification = active ? NSApplication.didBecomeActiveNotification : NSApplication.willResignActiveNotification
    #endif
    NotificationCenter.default.post(name: notification, object: nil)
    // NotificationCenter's callback forwards onto MainActor in a task.
    try await Task.sleep(for: .milliseconds(20))
  }

  private func eventually(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while !condition() {
      guard ContinuousClock.now < deadline else { throw CoreError(code: "lifecycle_test_timeout") }
      try await Task.sleep(for: .milliseconds(5))
    }
  }

  @Test func applicationNotificationsRefreshObservableResourcesAndStopAfterClose() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    #expect(clerk.user == nil)
    try await postActive(false)
    let before = capabilities.clientReads
    try await clerk.signIn.reset()
    #expect(capabilities.clientReads == before)
    try await postActive(true)
    try await eventually { clerk.sessions.contains { $0.id == "sess_native" } }
    #expect(clerk.session == nil)
    let after = capabilities.clientReads
    try await postActive(true)
    try await clerk.signIn.reset()
    #expect(capabilities.clientReads == after)
    clerk.close()
    try await postActive(false)
    try await postActive(true)
    #expect(capabilities.clientReads == after)
  }

  @Test func releasingTheLastOwnerTearsDownLifecycleObservation() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    var clerk: Clerk? = try await connect(capabilities)
    weak var runtime = try clerk?.context.requireRuntime()
    let reads = capabilities.clientReads
    clerk = nil
    try await eventually { runtime == nil }
    try await postActive(false)
    try await postActive(true)
    #expect(capabilities.clientReads == reads)
  }

  @Test func foregroundFailureIsNonfatalAndTheNextActivationRecovers() async throws {
    let capabilities = try LifecycleFailureCapabilities()
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let runtime = try clerk.context.requireRuntime()
    try await postActive(false)
    capabilities.failReload = true
    try await postActive(true)
    try await eventually { runtime.lastLifecycleError != nil }
    #expect(runtime.isAvailable)
    try await clerk.signIn.reset()
    #expect(clerk.user == nil)
    capabilities.failReload = false
    try await postActive(false)
    try await postActive(true)
    try await eventually { clerk.sessions.contains { $0.id == "sess_native" } }
    #expect(clerk.session == nil)
    #expect(runtime.isAvailable)
  }

  @Test func generatedResourcesExecuteThePackagedCore() async throws {
    try await PackageProof.run()
  }
}

@MainActor private final class LifecycleFailureCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var failReload = false
  var supported: [String] {
    base.supported
  }

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if failReload, capability == "http", try arguments.object()["url"]?.url().path.hasSuffix("/client") == true {
      return .object(["status": .number(422), "headers": .object([:]), "body": .string("{\"errors\":[{\"code\":\"fixture_reload_failed\",\"message\":\"Fixture reload failed\"}]}")])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
