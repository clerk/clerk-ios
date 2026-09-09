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

  @Test func sessionReloadReturnsReadableStateAfterTheOwnerStopsSelectingIt() async throws {
    for status in ["active", "pending", "expired"] {
      let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
      capabilities.clientResponse = capabilities.fixtures["authenticatedClient"]
      let clerk = try await connect(capabilities)
      defer { clerk.close() }
      let original = try #require(clerk.session)
      var session = try #require(capabilities.fixtures["session"]).object()
      session["status"] = .string(status)
      session["tasks"] = status == "pending" ? .array([.object(["key": .string("choose-organization")])]) : .array([])
      var client = try #require(capabilities.fixtures["authenticatedClient"]).object()
      client["sessions"] = .array([.object(session)])
      capabilities.sessionReloadResponse = .object(["response": .object(session), "client": .object(client)])
      let returned = try await original.reload()
      #expect(returned.id == "sess_native")
      #expect(returned.status.rawValue == status)
      #expect(!returned.isInvalidated)
      if status == "expired" {
        #expect(clerk.session == nil)
        #expect(original.isInvalidated)
        #expect(original !== returned)
      } else {
        #expect(clerk.session === original)
        #expect(returned === original)
        if status == "pending" { #expect(returned.currentTask?.key.rawValue == "choose-organization") }
      }
    }
  }

  @Test func missingAndPartialOrganizationSettingsDoNotPreventStartup() async throws {
    let cases: [JSONValue?] = [nil, .object([:]), .object(["enabled": .bool(true)]), .object(["enabled": .bool(true), "force_organization_selection": .bool(true)])]
    for settings in cases {
      let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
      var environment = try #require(capabilities.fixtures["environment"]).object()
      environment["organization_settings"] = settings
      capabilities.environmentResponse = .object(environment)
      let clerk = try await connect(capabilities)
      defer { clerk.close() }
      let values = clerk.environment.organizationSettings
      let expected = try settings?.object()
      #expect(values.enabled == (expected?["enabled"] == .bool(true)))
      #expect(values.forceOrganizationSelection == (expected?["force_organization_selection"] == .bool(true)))
      #expect(values.domains.enabled == false)
      #expect(values.domains.defaultRole == nil)
      #expect(values.maxAllowedMemberships == 1)
      let original = clerk.environment
      environment["organization_settings"] = .object(["enabled": .bool(true), "force_organization_selection": .bool(true)])
      capabilities.environmentResponse = .object(environment)
      let refreshed = try await original.reload()
      #expect(refreshed === original)
      #expect(clerk.environment.organizationSettings.forceOrganizationSelection == true)
      #expect(clerk.session == nil)
    }
  }

  @Test func generatedResourcesExecuteThePackagedCore() async throws {
    try await PackageProof.run()
  }

  @Test func replacingAnOwnerInvalidatesOldResourcesAndPreservesItsCredential() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    capabilities.credential = "existing-device-credential"
    capabilities.clientResponse = capabilities.fixtures["authenticatedClient"]
    let original = try await connect(capabilities)
    defer { original.close() }
    let oldSession = try #require(original.session)
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    do {
      _ = try ClerkConfiguration(publishableKey: "invalid", callbackURL: callback)
      Issue.record("Expected invalid replacement configuration to fail")
    } catch let error as CoreError {
      #expect(error.code == "invalid_publishable_key")
    }
    #expect(original.session === oldSession)
    #expect(!oldSession.isInvalidated)
    let credential = capabilities.credential
    #expect(credential != nil)
    original.close()
    #expect(oldSession.isInvalidated)
    #expect(capabilities.credential == credential)

    let replacement = try await connect(capabilities)
    defer { replacement.close() }
    let newSession = try #require(replacement.session)
    #expect(newSession.id == oldSession.id)
    #expect(newSession !== oldSession)
    let requestCount = capabilities.requests.count
    do {
      _ = try await oldSession.getToken()
      Issue.record("Expected the old session to reject work after close")
    } catch let error as CoreError {
      #expect(error.code == "stale_resource")
    }
    #expect(capabilities.requests.count == requestCount)
    #expect(replacement.session === newSession)
    #expect(!newSession.isInvalidated)
    let token = try await newSession.getToken()
    #expect(token != nil)
  }

  @Test func sessionReloadPublishesOrganizationSelectionBeforeCompletion() async throws {
    let capabilities = try FixtureCapabilities(data: PackageProof.fixtureData())
    func membership(_ id: String) -> JSONValue {
      .object([
        "object": .string("organization_membership"), "id": .string("membership_\(id)"),
        "role": .string("org:admin"), "role_name": .string("Admin"), "permissions": .array([]),
        "created_at": .number(1_700_000_000_000), "updated_at": .number(1_700_000_000_000),
        "organization": .object([
          "object": .string("organization"), "id": .string(id), "name": .string("Organization \(id)"),
          "slug": .string(id), "created_at": .number(1_700_000_000_000), "updated_at": .number(1_700_000_000_000),
        ]),
      ])
    }
    var session = try #require(capabilities.fixtures["session"]).object()
    var user = try #require(session["user"]).object()
    user["organization_memberships"] = .array([membership("org_one"), membership("org_two")])
    session["user"] = .object(user)
    session["last_active_organization_id"] = .string("org_one")
    var client = try #require(capabilities.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(session)])
    capabilities.clientResponse = .object(client)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let originalSession = try #require(clerk.session)
    #expect(clerk.organization?.id == "org_one")
    #expect(clerk.organization?.name == "Organization org_one")
    #expect(clerk.user?.organizationMemberships.first?.id == "membership_org_one")

    for selected: String? in ["org_two", nil] {
      session["last_active_organization_id"] = selected.map(JSONValue.string) ?? .null
      client["sessions"] = .array([.object(session)])
      capabilities.sessionReloadResponse = .object(["response": .object(session), "client": .object(client)])
      _ = try await originalSession.reload()
      #expect(clerk.session === originalSession)
      #expect(originalSession.lastActiveOrganizationId == selected)
      #expect(clerk.organization?.id == selected)
      #expect(clerk.user?.organizationMemberships.count == 2)
    }
  }

  @Test func olderClientResponseCannotRemoveANewerPendingTaskOrCredential() async throws {
    let capabilities = try OrderedClientResponseCapabilities()
    let clerk = try await connect(capabilities)
    defer { capabilities.release(); clerk.close() }
    let session = try #require(clerk.session)
    let old = Task { try await session.reload() }
    try await eventually { capabilities.waiting }
    _ = try await session.reload()
    #expect(clerk.session?.status == .pending)
    #expect(clerk.session?.currentTask?.key.rawValue == "choose-organization")
    capabilities.release()
    do {
      _ = try await old.value
      Issue.record("Expected the older client response to be rejected")
    } catch let error as CoreError {
      #expect(error.code == "stale_client_response")
    }
    #expect(clerk.session === session)
    #expect(session.status == .pending)
    #expect(session.currentTask?.key.rawValue == "choose-organization")
    #expect(capabilities.base.credential == "newer-response-credential")
    _ = try await session.reload()
    #expect(session.status == .pending)
  }

  @Test func canonicalClientRequiresANewOrRestoredCredential() async throws {
    let credentials: [String?] = [nil, "restored-client-credential"]
    for credential in credentials {
      let capabilities = try CredentiallessResponseCapabilities()
      capabilities.base.credential = credential
      if credential == nil {
        do {
          let clerk = try await connect(capabilities)
          clerk.close()
          Issue.record("Expected credentialless client initialization to fail")
        } catch let error as CoreError {
          #expect(error.code == "missing_client_credential")
        }
      } else {
        let clerk = try await connect(capabilities)
        #expect(clerk.session?.status == .active)
        clerk.close()
      }
      #expect(capabilities.base.credential == credential)
    }
  }
}

@MainActor private final class CredentiallessResponseCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = try #require(base.fixtures["authenticatedClient"])
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let result = try await base.perform(capability, arguments: arguments)
    guard capability == "http" else { return result }
    var response = try result.object()
    response["headers"] = .object([:])
    return .object(response)
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

@MainActor private final class OrderedClientResponseCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var waiting = false
  private var count = 0
  private var continuation: CheckedContinuation<Void, Never>?

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    var client = try #require(base.fixtures["authenticatedClient"]).object()
    client["object"] = .string("client")
    client["updated_at"] = .number(1_700_000_000_000)
    base.clientResponse = .object(client)
  }

  func release() {
    continuation?.resume()
    continuation = nil
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if try capability != "http" || (arguments.object()["url"]?.url().path.hasSuffix("/sessions/sess_native")) != true {
      return try await base.perform(capability, arguments: arguments)
    }
    count += 1
    let older = count == 1
    if older {
      waiting = true
      await withCheckedContinuation { continuation = $0 }
    }
    var session = try #require(base.fixtures["session"]).object()
    var client = try #require(base.clientResponse).object()
    if !older {
      session["status"] = .string("pending")
      session["tasks"] = .array([.object(["key": .string("choose-organization")])])
      client["updated_at"] = .number(1_700_000_001_000)
    }
    client["sessions"] = .array([.object(session)])
    let payload = JSONValue.object(["response": .object(session), "client": .object(client)])
    return try .object([
      "status": .number(200),
      "headers": .object([
        "date": .string(older ? "Wed, 09 Sep 2026 16:00:00 GMT" : "Wed, 09 Sep 2026 16:00:01 GMT"),
        "authorization": .string(older ? "older-response-credential" : "newer-response-credential"),
      ]),
      "body": .string(String(decoding: JSONEncoder().encode(payload), as: UTF8.self)),
    ])
  }
}
