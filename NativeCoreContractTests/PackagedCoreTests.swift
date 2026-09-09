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

  @Test func previousNativeEmailLinkCallbackFormsCompleteWithoutImplicitActivation() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    try await clerk.signUp.create(.init(emailAddress: "test@example.com"))
    try await clerk.signUp.verifications.sendEmailLink(.init())
    let callback = try #require(URL(string: "clerk-test://sso-callback/#flow_id=sua_native&approval_token=fixture_approval"))
    let result = try await clerk.handleAuthCallback(callback)
    guard case .case2(let value) = result else { Issue.record("Expected the original sign-up resource"); return }
    #expect(value.signUp === clerk.signUp)
    #expect(clerk.signUp.status == .complete)
    #expect(clerk.session == nil)
    #expect(capabilities.authRecord == nil)
  }

  @Test func authRequestsUseTheDeviceLocaleAndAllowExplicitSignUpLocale() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    func requestedLocale() throws -> String? {
      let request = try #require(capabilities.requests.last)
      let body = try #require(request["body"]).string()
      var components = URLComponents()
      components.percentEncodedQuery = body
      return components.queryItems?.first { $0.name == "locale" }?.value
    }
    let locale = Locale.preferredLanguages.first ?? Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    try await clerk.signIn.create(.init(identifier: "test@example.com"))
    #expect(try requestedLocale() == locale)
    try await clerk.signUp.create(.init(emailAddress: "test@example.com"))
    #expect(try requestedLocale() == locale)
    try await clerk.signUp.create(.init(emailAddress: "test@example.com", locale: "de-DE"))
    #expect(try requestedLocale() == "de-DE")
  }

  @Test func structuredErrorsPreserveServerStatusRetryAndTrace() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    capabilities.nextAuthErrorStatus = 429
    capabilities.nextAuthErrorHeaders = ["retry-after": .string("7")]
    capabilities.nextAuthError = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"clerk_trace_id":"fixture-trace-123","errors":[{"code":"rate_limited","message":"Short message","long_message":"Try again later","meta":{"param_name":"identifier","password":"must-not-cross"}},{"code":"second_error","message":"Another error"}]}"#.utf8))
    do {
      try await clerk.signIn.create(.init(identifier: "test@example.com"))
      Issue.record("Expected a structured Clerk error")
    } catch let error as CoreError {
      #expect(error.kind == .clerk)
      #expect(error.status == 429)
      #expect(error.retryAfter == 7)
      #expect(error.clerkTraceId == "fixture-trace-123")
      #expect(error.errors.count == 2)
      #expect(error.errors.first?.meta?.paramName == "identifier")
      #expect(error.localizedDescription == "Try again later")
      let details = try JSONEncoder().encode(error.details)
      #expect(!String(decoding: details, as: UTF8.self).contains("must-not-cross"))
      #expect(clerk.session == nil)
    }
  }

  @Test func factorDiscriminantsPreserveDeviceAndRecoveryFields() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    capabilities.signInFirstFactors = try JSONDecoder().decode(JSONValue.self, from: Data(#"[{"strategy":"phone_code","phone_number_id":"idn_phone","safe_identifier":"+15555550123","primary":true,"default":true},{"strategy":"trusted_device","trusted_device_id":"tdc_123","safe_identifier":"Test device"},{"strategy":"reset_password_phone_code","phone_number_id":"idn_reset","safe_identifier":"reset-phone"},{"strategy":"enterprise_sso","enterprise_connection_id":"ec_123","enterprise_connection_name":"Acme"},{"strategy":"oauth_future_provider"}]"#.utf8))
    try await clerk.signIn.create(.init(identifier: "test@example.com"))
    let factors = clerk.signIn.supportedFirstFactors
    let device = try #require(factors.first { $0.strategy == "trusted_device" })
    guard case .case11(let credential) = device else { Issue.record("Expected trusted-device factor"); return }
    #expect(credential.trustedDeviceId == .value("tdc_123"))
    #expect(credential.safeIdentifier == .value("Test device"))
    let reset = try #require(factors.first { $0.strategy == "reset_password_phone_code" })
    guard case .case9(let recovery) = reset else { Issue.record("Expected phone recovery factor"); return }
    #expect(recovery.phoneNumberId == "idn_reset")
    let phone = try #require(factors.first { $0.strategy == "phone_code" })
    guard case .case3(let value) = phone else { Issue.record("Expected phone factor"); return }
    #expect(value.default == true && value.primary == true)
    let enterprise = try #require(factors.first { $0.strategy == "enterprise_sso" })
    guard case .case8(let connection) = enterprise else { Issue.record("Expected enterprise factor"); return }
    #expect(connection.enterpriseConnectionId == "ec_123")
    #expect(factors.contains { $0.strategy == "oauth_future_provider" })
    #expect(clerk.session == nil)
  }

  @Test func networkRestorationRefreshesTheOwnerAndStopsAfterClose() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    let probe = NetworkProbe()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: capabilities) { runtime in
      observeNetworkConnectivity(runtime) { receive in
        probe.receive = receive
        return { Task { @MainActor in probe.stopped = true } }
      }
    }
    defer { clerk.close() }
    let runtime = try clerk.context.requireRuntime()
    runtime.setApplicationActive(true)
    try await Task.sleep(for: .milliseconds(30))
    let before = capabilities.clientReads
    probe.receive?(false)
    try await Task.sleep(for: .milliseconds(20))
    probe.receive?(true)
    try await eventually { capabilities.clientReads > before }
    try await eventually { clerk.sessions.contains { $0.id == "sess_native" } }
    #expect(clerk.session == nil)
    let after = capabilities.clientReads
    probe.receive?(true)
    try await Task.sleep(for: .milliseconds(20))
    #expect(capabilities.clientReads == after)
    clerk.close()
    try await eventually { probe.stopped }
    probe.receive?(false)
    probe.receive?(true)
    try await Task.sleep(for: .milliseconds(20))
    #expect(capabilities.clientReads == after)
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

@MainActor private final class NetworkProbe {
  var receive: (@Sendable (Bool) -> Void)?
  var stopped = false
}
