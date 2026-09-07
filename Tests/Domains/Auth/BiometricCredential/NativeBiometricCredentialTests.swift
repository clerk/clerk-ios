#if !os(watchOS)
import ClerkJSCore
@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct NativeBiometricCredentialTests {
  @Test(arguments: [BiometricCredentialPolicy.biometryCurrentSet, .biometryAny, .biometryOrDevicePasscode])
  func enrollmentSignsExactChallengeAndSavesLocalOnlyHint(policy: BiometricCredentialPolicy) async throws {
    let fixture = try await biometricHarness()
    let signed = LockIsolated<[String]>([])
    fixture.keys.signHandler = { data, key, reason in
      signed.setValue([data, key, reason ?? ""])
      return .init(clientData: data, signature: "signature-exact")
    }
    let result = try await Clerk.shared.biometricCredentials.enroll(name: "Phone", identifierHint: " Ada@Example.COM ", reason: "Enroll this phone", policy: policy)
    #expect(result.id == "tdc_new")
    let record = try #require(try fixture.store.credential(id: result.id))
    #expect(record.userID == "user_fixture")
    #expect(record.identifierHint == "ada@example.com")
    #expect(record.policy == policy)
    #expect(signed.value == [biometricClientData, record.localKeyId, "Enroll this phone"])
    let requests = try await fixture.requests()
    #expect(requests.map(\.path) == ["/v1/me/biometric_credentials/prepare", "/v1/me/biometric_credentials/attempt"])
    #expect(requests[0].body["public_key_jwk"] == BiometricCredentialLocalKey.mock.publicKeyJWK)
    #expect(requests[0].body["platform"] == "ios")
    #expect(requests[0].body["algorithm"] == "ES256")
    #expect(requests[1].body["signature"] == "signature-exact")
    #expect(requests[1].body["client_data"] == biometricClientData)
    #expect(requests.allSatisfy { $0.session == "sess_fixture" && $0.body["identifier_hint"] == nil })
  }

  @Test
  func enrollmentReplacesThisInstallationAcrossUsersAndKeepsOtherApps() async throws {
    let fixture = try await biometricHarness()
    try fixture.save(id: "tdc_old", user: "other-user")
    try fixture.save(id: "tdc_other_app", app: "com.other.app")
    _ = try await Clerk.shared.biometricCredentials.enroll()
    #expect(try fixture.store.all().map(\.id).sorted() == ["tdc_new", "tdc_other_app"])
    #expect(fixture.deleted.value == ["key_tdc_old"])
  }

  @Test(arguments: ["prepare_failure", "attempt_failure", "malformed_challenge"])
  func failedEnrollmentDeletesNewKeyAndKeepsPreviousCredential(scenario: String) async throws {
    let fixture = try await biometricHarness(scenario: scenario)
    try fixture.save(id: "tdc_old")
    await #expect(throws: Error.self) { try await Clerk.shared.biometricCredentials.enroll() }
    #expect(try fixture.store.all().map(\.id) == ["tdc_old"])
    #expect(fixture.deleted.value == [BiometricCredentialLocalKey.mock.localKeyId])
    #expect(try await fixture.requests().allSatisfy { !$0.path.hasSuffix("/tdc_new") })
  }

  @Test
  func failedLocalSaveRevokesServerCredentialAndDeletesGeneratedKey() async throws {
    let keychain = BiometricTestKeychain()
    let fixture = try await biometricHarness(keychain: keychain)
    keychain.failBiometricWrites = true
    await #expect(throws: Error.self) { try await Clerk.shared.biometricCredentials.enroll() }
    #expect(try await fixture.requests().last?.path == "/v1/me/biometric_credentials/tdc_new")
    #expect(try await fixture.requests().last?.session == "sess_fixture")
    #expect(fixture.deleted.value == [BiometricCredentialLocalKey.mock.localKeyId])
    #expect(try fixture.store.all().isEmpty)
  }

  @Test(arguments: [BiometricCredentialKeyManagerError.biometricAuthenticationCanceled, .keyNotFound, .signingFailed("fixture"), .deletionFailed(-42)])
  func preservesTypedAppleKeyErrors(error: BiometricCredentialKeyManagerError) async throws {
    let fixture = try await biometricHarness()
    fixture.keys.signHandler = { _, _, _ in throw error }
    await #expect(throws: error) { try await Clerk.shared.biometricCredentials.enroll() }
    #expect(fixture.deleted.value == [BiometricCredentialLocalKey.mock.localKeyId])
    #expect(try await fixture.requests().count == 1)
  }

  @Test(arguments: ["pending", "expired", "signed_out"])
  func enrollmentRequiresActiveOrPendingSession(status: String) async throws {
    let fixture = try await biometricHarness(signedIn: status != "signed_out")
    if status != "signed_out" {
      _ = try await fixture.host.runtime.evaluateJSON("(__clerkInstance.session.status = '\(status)', true)")
    }
    if status == "pending" {
      #expect(try await Clerk.shared.biometricCredentials.enroll().id == "tdc_new")
    } else {
      await #expect(throws: Error.self) { try await Clerk.shared.biometricCredentials.enroll() }
      #expect(try await fixture.requests().isEmpty)
    }
  }

  @Test
  func publicSignInUsesSelectedLocalCredentialAndExactSignature() async throws {
    let fixture = try await biometricHarness(signedIn: false)
    try fixture.save(id: "tdc_old", hint: "other@example.com", date: 1)
    try fixture.save(id: "tdc_selected", hint: "ada@example.com", date: 2)
    try fixture.save(id: "tdc_foreign", app: "com.other.app", date: 3)
    let signed = LockIsolated<[String]>([])
    fixture.keys.signHandler = { data, key, reason in
      signed.setValue([data, key, reason ?? ""])
      return .init(clientData: data, signature: "signed")
    }
    let result = try await Clerk.shared.auth.signInWithBiometrics(identifierHint: " ADA@example.com ", reason: "Unlock")
    #expect(result.id == "sia_biometric")
    #expect(result.status == .complete)
    #expect(Clerk.shared.client?.signIn?.id == result.id)
    #expect(signed.value == [biometricClientData, "key_tdc_selected", "Unlock"])
    let requests = try await fixture.requests()
    #expect(requests.map(\.path) == ["/v1/client/sign_ins", "/v1/client/sign_ins/sia_biometric/attempt_first_factor"])
    #expect(requests.allSatisfy { $0.body["trusted_device_id"] == "tdc_selected" && $0.body["strategy"] == "biometric_credential" && $0.body["identifier_hint"] == nil })
    #expect(requests.last?.body["client_data"] == biometricClientData)
    #expect(requests.last?.body["signature"] == "signed")
  }

  @Test(arguments: ["missing_create", "missing_attempt", "unrelated_error", "no_challenge"])
  func failedSignInForgetsOnlyServerMissingCredentials(scenario: String) async throws {
    let fixture = try await biometricHarness(signedIn: false, scenario: scenario)
    try fixture.save(id: "tdc_selected")
    await #expect(throws: Error.self) { try await Clerk.shared.auth.signInWithBiometrics() }
    let missing = scenario.hasPrefix("missing_")
    #expect(try (fixture.store.all().isEmpty) == missing)
    #expect(fixture.deleted.value == (missing ? ["key_tdc_selected"] : []))
  }

  @Test
  func reconciliationSelectsActiveUsersCredentialAfterRemovingRevokedNewerEntry() async throws {
    let fixture = try await biometricHarness(scenario: "reconcile")
    try fixture.save(id: "tdc_selected", hint: "old@example.com", date: 1)
    try fixture.save(id: "tdc_revoked", date: 2)
    try fixture.save(id: "tdc_foreign", user: "other-user", date: 3)
    #expect(try await Clerk.shared.biometricCredentials.currentUserAvailability() == .available)
    #expect(fixture.deleted.value == ["key_tdc_revoked"])
    #expect(try fixture.store.credential(id: "tdc_foreign") != nil)
    #expect(try await fixture.requests().count == 1)
    #expect(try await Clerk.shared.biometricCredentials.revokeCurrentDeviceCredential()?.id == "tdc_selected")
    #expect(try fixture.store.credential(id: "tdc_selected") == nil)
  }

  @Test(arguments: ["valid", "invalid", "missing", "native_api_disabled", "feature_not_enabled", "transient"])
  func validationPreservesTransientCredentialsAndClassifiesServerOutcomes(scenario: String) async throws {
    let fixture = try await biometricHarness(signedIn: false, scenario: "validation_" + scenario)
    try fixture.save(id: "tdc_selected")
    let result = await Clerk.shared.biometricCredentials.validateLocalCredentialIfPossible()
    let expected: BiometricCredentialValidationResult = switch scenario {
    case "valid": .valid
    case "invalid", "missing": .invalid(.serverCredentialMissing)
    case "native_api_disabled": .invalid(.nativeAPIDisabled)
    case "feature_not_enabled": .invalid(.featureDisabled)
    default: .inconclusive
    }
    #expect(result == expected)
    #expect(try (fixture.store.all().isEmpty) == ["invalid", "missing"].contains(scenario))
  }

  @Test
  func validationTriesOlderCredentialWhenNewestWasRemovedOnServer() async throws {
    let fixture = try await biometricHarness(signedIn: false, scenario: "validation_skip_newest")
    try fixture.save(id: "tdc_selected", date: 1)
    try fixture.save(id: "tdc_missing", date: 2)
    #expect(await Clerk.shared.biometricCredentials.validateLocalCredentialIfPossible() == .valid)
    #expect(try fixture.store.all().map(\.id) == ["tdc_selected"])
  }

  @Test
  func identityChangeDuringEnrollmentStopsBeforeSigningAndCleansUpKey() async throws {
    let fixture = try await biometricHarness(scenario: "hold_prepare")
    let enrollment = Task { try await Clerk.shared.biometricCredentials.enroll() }
    try await fixture.waitForHold()
    _ = try await fixture.host.runtime.evaluateJSON("(__clerkInstance.session = null, releaseBiometric(), true)")
    await #expect(throws: Error.self) { try await enrollment.value }
    #expect(try await fixture.requests().count == 1)
    #expect(fixture.deleted.value == [BiometricCredentialLocalKey.mock.localKeyId])
  }

  @Test(arguments: [true, false])
  func disposalCleansOnlyUncommittedEnrollmentKeys(completed: Bool) async throws {
    let fixture = try await biometricHarness(scenario: completed ? "success" : "hold_prepare")
    let enrollment = Task { try await Clerk.shared.biometricCredentials.enroll() }
    if completed { _ = try await enrollment.value }
    else { try await fixture.waitForHold() }
    await Clerk.disposeEngine()
    if !completed { await #expect(throws: Error.self) { try await enrollment.value } }
    for _ in 0 ..< 100 {
      if !fixture.deleted.value.isEmpty || completed { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(fixture.deleted.value == (completed ? [] : [BiometricCredentialLocalKey.mock.localKeyId]))
    #expect(try fixture.store.all().count == (completed ? 1 : 0))
  }

  @Test(arguments: ["expired", "signed_out"])
  func availabilityWithoutActiveSessionUsesOnlyLocalState(status: String) async throws {
    let fixture = try await biometricHarness(signedIn: status != "signed_out")
    if status == "expired" {
      _ = try await fixture.host.runtime.evaluateJSON("(__clerkInstance.session.status = 'expired', true)")
    }
    try fixture.save(id: "tdc_selected")
    #expect(try await Clerk.shared.biometricCredentials.availability() == .available)
    #expect(try await fixture.requests().isEmpty)
  }

  @Test
  func publicListAndRevokeReturnServerResultEvenIfLocalCleanupFails() async throws {
    let fixture = try await biometricHarness()
    try fixture.save(id: "tdc_selected")
    #expect(try await Clerk.shared.biometricCredentials.list().map(\.id) == ["tdc_selected", "tdc_revoked"])
    fixture.keys.deleteKeyHandler = { _ in throw BiometricCredentialKeyManagerError.deletionFailed(-42) }
    #expect(try await Clerk.shared.biometricCredentials.revoke(id: "tdc_selected").status == .revoked)
    #expect(try fixture.store.credential(id: "tdc_selected") != nil)
  }

  @Test(arguments: ["api", "feature"])
  func disabledSharedSettingsPreventNetworkAndKeyGeneration(setting: String) async throws {
    let fixture = try await biometricHarness()
    let name = setting == "api" ? "api_enabled" : "biometric_sign_in_enabled"
    _ = try await fixture.host.runtime.evaluateJSON("(__clerkInstance.__internal_environment.authConfig.nativeSettings['\(name)'] = false, true)")
    await #expect(throws: Error.self) { try await Clerk.shared.biometricCredentials.enroll() }
    #expect(try await Clerk.shared.biometricCredentials.availability() == .unavailable(setting == "api" ? .nativeAPIDisabled : .featureDisabled))
    #expect(try await fixture.requests().isEmpty)
    #expect(fixture.deleted.value.isEmpty)
  }

  @Test
  func changedSignInDuringApplePromptCannotAttemptOldChallenge() async throws {
    let fixture = try await biometricHarness(signedIn: false)
    try fixture.save(id: "tdc_selected")
    let prompted = LockIsolated(false)
    fixture.keys.signHandler = { data, _, _ in
      prompted.setValue(true)
      Clerk.shared.identityController.fenceClientResponses()
      return .init(clientData: data, signature: "signed")
    }
    await #expect(throws: Error.self) { try await Clerk.shared.auth.signInWithBiometrics() }
    #expect(prompted.value)
    #expect(try fixture.store.all().count == 1)
  }
}

private let biometricClientData = "{\"challenge_id\":\"challenge_bio\",\"challenge\":\"exact bytes\"}"

@MainActor
private struct BiometricHarness {
  let host: ClerkJSHost
  let keys: MockBiometricCredentialKeyManager
  let store: BiometricCredentialLocalStore
  let deleted: LockIsolated<[String]>

  func save(id: String, user: String = "user_fixture", app: String = "com.clerk.example", hint: String? = nil, date: Double = 1) throws {
    try store.save(.init(id: id, localKeyId: "key_" + id, userID: user, appIdentifier: app, identifierHint: hint, createdAt: Date(timeIntervalSince1970: date), updatedAt: Date(timeIntervalSince1970: date)))
  }

  struct Request: Decodable {
    let path: String
    let body: [String: String]
    let session: String?
  }

  func requests() async throws -> [Request] {
    let json = try await host.runtime.evaluateJSON("biometricRequests")
    return try JSONDecoder().decode([Request].self, from: Data(json.utf8))
  }

  func waitForHold() async throws {
    for _ in 0 ..< 100 {
      if try await host.runtime.evaluateJSON("typeof releaseBiometric === 'function'") == "true" { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    throw ClerkClientError(message: "Biometric request did not start")
  }
}

private final class BiometricTestKeychain: KeychainStorage, @unchecked Sendable {
  let backing = InMemoryKeychain()
  var failBiometricWrites = false
  func set(_ data: Data, forKey key: String) throws {
    if key == ClerkKeychainKey.biometricCredentials.rawValue, failBiometricWrites { throw ClerkClientError(message: "Cannot save local credential") }
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}

@MainActor
private func biometricHarness(signedIn: Bool = true, scenario: String = "success", keychain: BiometricTestKeychain = .init()) async throws -> BiometricHarness {
  let deleted = LockIsolated<[String]>([])
  let keys = MockBiometricCredentialKeyManager(deleteKey: { key in deleted.withValue { $0.append(key) } })
  let store = BiometricCredentialLocalStore(keychain: keychain)
  let host = try await configureEmbeddedClerkForTesting(signedIn: signedIn, biometricAppIdentifier: "com.clerk.example") { clerk in
    clerk.dependencies = MockDependencyContainer(apiClient: createMockAPIClient(), biometricCredentialKeyManager: keys, biometricCredentialStore: store)
  }
  let settings = try String(decoding: JSONEncoder().encode(["scenario": scenario, "clientData": biometricClientData]), as: UTF8.self)
  _ = try await host.runtime.evaluateJSON("""
    (function() {
      var settings = \(settings);
      var clerk = __clerkInstance;
      clerk.__internal_environment.authConfig.nativeSettings = {api_enabled:true,biometric_sign_in_enabled:true};
      clerk.updateEnvironment(clerk.__internal_environment);
      var client = clerk.client.__internal_toSnapshot();
      var credential = {object:'trusted_device',id:'tdc_new',platform:'ios',app_identifier:'com.clerk.example',algorithm:'ES256',status:'active',created_at:Date.now(),updated_at:Date.now()};
      var challenge = {object:'trusted_device_challenge',challenge:'challenge',challenge_id:'challenge_bio',client_data:settings.clientData,expires_at:Date.now()+600000,algorithm:'ES256'};
      var signIn = {object:'sign_in',id:'sia_biometric',status:'needs_first_factor',supported_identifiers:[],supported_first_factors:[],supported_second_factors:[],first_factor_verification:{status:'unverified',strategy:'biometric_credential',trusted_device_challenge:challenge},second_factor_verification:null,user_data:{},created_session_id:null};
      globalThis.biometricRequests = [];
      globalThis.fetch = async function(url, options) {
        var body = Object.fromEntries(new URLSearchParams(options.body || ''));
        biometricRequests.push({path:url.pathname,body:body,session:url.searchParams.get('_clerk_session_id')});
        var response, failure, meta;
        if (url.pathname.endsWith('/prepare')) {
          if (settings.scenario === 'hold_prepare') await new Promise(resolve => { globalThis.releaseBiometric = resolve; });
          response = settings.scenario === 'malformed_challenge' ? {} : challenge;
          if (settings.scenario === 'prepare_failure') failure = 'prepare_failed';
        } else if (url.pathname.endsWith('/attempt')) {
          response = credential;
          if (settings.scenario === 'attempt_failure') failure = 'attempt_failed';
        } else if (url.pathname.endsWith('/validate')) {
          response = {valid:settings.scenario === 'validation_valid' || (settings.scenario === 'validation_skip_newest' && body.trusted_device_id === 'tdc_selected')};
          if (settings.scenario === 'validation_missing') { failure = 'trusted_device_not_registered'; meta = {param_name:'trusted_device_id'}; }
          else if (['validation_native_api_disabled','validation_feature_not_enabled','validation_transient'].includes(settings.scenario)) failure = settings.scenario.slice(11);
        } else if (url.pathname.endsWith('/biometric_credentials')) {
          response = [{...credential,id:'tdc_selected'},{...credential,id:'tdc_revoked',status:'revoked'}];
        } else if (url.pathname.includes('/me/biometric_credentials/')) {
          response = {...credential,id:url.pathname.split('/').pop(),status:'revoked'};
        } else if (url.pathname.endsWith('/sign_ins') || url.pathname.endsWith('/attempt_first_factor')) {
          var attempt = url.pathname.endsWith('/attempt_first_factor');
          if (settings.scenario === (attempt ? 'missing_attempt' : 'missing_create')) { failure = 'form_resource_not_found'; meta = {param_name:'trusted_device_id'}; }
          if (settings.scenario === 'unrelated_error') { failure = 'form_resource_not_found'; meta = {param_name:'identifier'}; }
          if (settings.scenario === 'no_challenge') delete signIn.first_factor_verification.trusted_device_challenge;
          if (attempt) { signIn.status = 'complete'; signIn.first_factor_verification.status = 'verified'; }
          response = signIn;
          if (!client.id) client.id = 'client_biometric';
          client.sign_in = signIn;
        } else throw new Error('Unexpected biometric request ' + url.pathname);
        var headers = new Headers();
        if (url.pathname.endsWith('/sign_ins') && !failure) headers.set('authorization', 'biometric-client-token');
        return {status:failure?422:200,ok:!failure,headers,json:async () => failure ? {errors:[{code:failure,message:'Biometric failure',meta}]} : {response,client}};
      };
      return true;
    })()
    """)
  return .init(host: host, keys: keys, store: store, deleted: deleted)
}
#endif
