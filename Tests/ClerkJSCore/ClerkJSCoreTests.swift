#if !os(watchOS)
@testable import ClerkJSCore
import ClerkWatchCompanion
import Foundation
import Testing

private let mockPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

struct ClerkJSCoreTests {
  @Test
  func evaluateExposesClerkConstructorWithoutWindow() async throws {
    let runtime = ClerkJSRuntime()
    let clerkType = try await decodeJSONString(runtime.evaluateJSON("typeof Clerk"))
    #expect(clerkType == "function")
    let windowType = try await decodeJSONString(runtime.evaluateJSON("typeof window"))
    #expect(windowType == "undefined")
  }

  @Test
  func constructDoesNotThrow() async throws {
    let runtime = ClerkJSRuntime()
    let result = try await decodeJSONBool(
      runtime.evaluateJSON(
        "(function(){ new Clerk('\(mockPublishableKey)'); return true; })()"
      )
    )
    #expect(result)
  }

  @Test
  func polyfillsAreInstalled() async throws {
    let runtime = ClerkJSRuntime()
    let fetchType = try await decodeJSONString(runtime.evaluateJSON("typeof fetch"))
    #expect(fetchType == "function")
    let online = try await decodeJSONBool(runtime.evaluateJSON("navigator.onLine === true"))
    #expect(online)
    let windowType = try await decodeJSONBool(runtime.evaluateJSON("typeof window === 'undefined'"))
    #expect(windowType)
    let searchEntries = try await decodeJSONBool(
      runtime.evaluateJSON("typeof new URLSearchParams('a=1').entries === 'function'")
    )
    #expect(searchEntries)
    let headerEntries = try await decodeJSONBool(
      runtime.evaluateJSON("typeof new Headers({a: '1'}).entries === 'function'")
    )
    #expect(headerEntries)
    let assignedPath = try await decodeJSONString(
      runtime.evaluateJSON(
        """
        (function(){
          var url = new URL('https://example.com');
          Object.assign(url, { pathname: 'v1/client' });
          return url.href;
        })()
        """
      )
    )
    #expect(assignedPath == "https://example.com/v1/client")
    let copiedSearch = try await decodeJSONString(
      runtime.evaluateJSON("new URLSearchParams(new URLSearchParams('a=1')).get('a')")
    )
    #expect(copiedSearch == "1")
    let copiedHeader = try await decodeJSONString(
      runtime.evaluateJSON("new Headers(new Headers({a: '1'})).get('a')")
    )
    #expect(copiedHeader == "1")
    let unpaddedAtob = try await decodeJSONString(runtime.evaluateJSON("atob('YQ')"))
    #expect(unpaddedAtob == "a")
    let unpaddedJSON = try await decodeJSONBool(
      runtime.evaluateJSON("JSON.parse(atob('eyJ4IjoxfQ')).x === 1")
    )
    #expect(unpaddedJSON)
  }

  @Test
  func generatedEnvironmentDecodesSnapshotFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    let data = try Data(contentsOf: url)
    let environment = try JSONDecoder().decode(Environment.self, from: data)
    #expect(environment.id == "env_fixture")
    #expect(environment.object == "environment")
  }

  @Test
  func generatedClientDecodesUnsignedFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let data = try Data(contentsOf: url)
    let client = try JSONDecoder().decode(Client.self, from: data)
    #expect(client.id == "client_fixture")
    #expect(client.object == "client")
    #expect(client.signIn == nil)
    #expect(client.signUp == nil)
    #expect(client.sessions.isEmpty)
  }

  @Test
  func memoryTokenCacheRoundTripThroughHost() async throws {
    let cache = ClerkJSTokenCache.memory()
    let runtime = ClerkJSRuntime(tokenCache: cache)
    let saved = try await decodeJSONBool(
      runtime.evaluateJSON(
        """
        (async function() {
          await __clerkNativeSaveToken('host-jwt');
          return true;
        })()
        """
      )
    )
    #expect(saved)
    #expect(await cache.getToken() == "host-jwt")
    let read = try await decodeJSONString(runtime.evaluateJSON("(__clerkNativeGetToken())"))
    #expect(read == "host-jwt")
  }

  @Test
  func resourceCacheHookReturnsNullsWhenEmpty() async throws {
    let cache = ClerkJSResourceCache.memory()
    let runtime = ClerkJSRuntime(resourceCache: cache)
    let payload = try await decodeCachedResources(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.resourceCacheInstallSource)
          return await clerk.__internal_getCachedResources();
        })()
        """
      )
    )
    #expect(payload.client == nil)
    #expect(payload.environment == nil)
  }

  @Test
  func resourceCacheHookReturnsSavedSnapshots() async throws {
    let cache = ClerkJSResourceCache.memory()
    let client = try #require(#"{"object":"client","id":"client_hook"}"#.data(using: .utf8))
    let environment = try #require(#"{"object":"environment","id":"env_hook"}"#.data(using: .utf8))
    await cache.save(ClerkJSCachedResources(client: client, environment: environment))
    let runtime = ClerkJSRuntime(resourceCache: cache)
    let payload = try await decodeCachedResources(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.resourceCacheInstallSource)
          return await clerk.__internal_getCachedResources();
        })()
        """
      )
    )
    #expect(payload.client?.object == "client")
    #expect(payload.client?.id == "client_hook")
    #expect(payload.environment?.object == "environment")
    #expect(payload.environment?.id == "env_hook")
  }

  @Test
  func callOnResourceReturningInvokesFactoryThenMethod() async throws {
    let runtime = ClerkJSRuntime()
    _ = try await runtime.evaluateJSON(
      """
      (function() {
        globalThis.__clerkInstance = {
          getOrganization: function(id) {
            return Promise.resolve({
              id: id,
              update: function(params) {
                return Promise.resolve({ id: id, name: params.name, slug: params.slug });
              }
            });
          }
        };
        return true;
      })()
      """
    )
    let json = try await runtime.callOnResourceReturning(
      factoryPath: "__clerkInstance.getOrganization",
      id: "org_1",
      method: "update",
      argsJSON: #"{"name":"Acme","slug":"acme"}"#
    )
    let payload = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    #expect(payload?["id"] as? String == "org_1")
    #expect(payload?["name"] as? String == "Acme")
    #expect(payload?["slug"] as? String == "acme")
  }

  @Test
  func callOnResourceStepsFindsListedChildThenInvokesMethod() async throws {
    let runtime = ClerkJSRuntime()
    _ = try await runtime.evaluateJSON(
      """
      (function() {
        globalThis.__clerkInstance = {
          getOrganization: function(id) {
            return Promise.resolve({
              getInvitations: function() {
                return Promise.resolve({
                  data: [
                    { id: 'inv_1', revoke: function() { return Promise.resolve({ id: 'inv_1', status: 'revoked' }); } },
                    { id: 'inv_2', revoke: function() { return Promise.resolve({ id: 'inv_2', status: 'revoked' }); } }
                  ]
                });
              }
            });
          }
        };
        return true;
      })()
      """
    )
    let json = try await runtime.callOnResourceSteps(
      receiverPath: "__clerkInstance.getOrganization",
      receiverArgJSON: #""org_1""#,
      stepsJSON: #"[{"method":"getInvitations","args":{"pageSize":100},"findId":"inv_2"},{"method":"revoke","args":{}}]"#
    )
    let payload = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    #expect(payload?["id"] as? String == "inv_2")
    #expect(payload?["status"] as? String == "revoked")
  }

  @Test
  func callOnResourceStepsPicksChildFromReceiverArray() async throws {
    let runtime = ClerkJSRuntime()
    _ = try await runtime.evaluateJSON(
      """
      (function() {
        globalThis.__clerkInstance = {
          user: {
            emailAddresses: [
              { id: 'idn_1', prepareVerification: function(params) { return Promise.resolve({ id: 'idn_1', strategy: params.strategy }); } },
              { id: 'idn_2', prepareVerification: function(params) { return Promise.resolve({ id: 'idn_2', strategy: params.strategy }); } }
            ]
          }
        };
        return true;
      })()
      """
    )
    let json = try await runtime.callOnResourceSteps(
      receiverPath: "__clerkInstance.user",
      receiverArgJSON: "null",
      stepsJSON: #"[{"pick":"emailAddresses","findId":"idn_2"},{"method":"prepareVerification","args":{"strategy":"email_code"}}]"#
    )
    let payload = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    #expect(payload?["id"] as? String == "idn_2")
    #expect(payload?["strategy"] as? String == "email_code")
  }

  @Test
  func applyFAPIClientJSONHydratesJSSessions() async throws {
    let runtime = ClerkJSRuntime()
    _ = try await runtime.evaluateJSON(
      """
      (function() {
        globalThis.__clerkInstance = {
          client: {
            sessions: [],
            fromJSON: function(payload) {
              this.sessions = (payload.sessions || []).map(function(session) {
                return { id: session.id };
              });
              return this;
            }
          }
        };
        return true;
      })()
      """
    )
    let payload = try #require(
      #"{"object":"client","id":"client_apply","sessions":[{"id":"sess_apply"}]}"#.data(using: .utf8)
    )
    let applied = try await runtime.applyFAPIClientJSON(payload)
    #expect(applied)
    let count = try await JSONDecoder().decode(
      Int.self,
      from: Data((runtime.evaluateJSON("globalThis.__clerkInstance.client.sessions.length")).utf8)
    )
    #expect(count == 1)
    let prefix = try await decodeJSONString(
      runtime.evaluateJSON("globalThis.__clerkInstance.client.sessions[0].id.slice(0, 5)")
    )
    #expect(prefix == "sess_")
  }

  @Test
  func applyClientJSONScriptKeepsRawFAPIUserDataNull() throws {
    let url = try #require(Bundle.module.url(forResource: "null-user-data-client", withExtension: "json"))
    let data = try Data(contentsOf: url)
    let script = try #require(NativeHost.applyClientJSONScript(data))
    let payload = try applyScriptPayload(script)
    let signIn = try #require(payload["sign_in"] as? [String: Any])
    #expect(signIn["user_data"] is NSNull)

    let normalized = try FAPIJSON.normalizeClientJSON(data)
    let normalizedPayload = try applyScriptPayload(#require(NativeHost.applyClientJSONScript(normalized)))
    let normalizedSignIn = try #require(normalizedPayload["sign_in"] as? [String: Any])
    let userData = try #require(normalizedSignIn["user_data"] as? [String: Any])
    #expect(userData["image_url"] as? String == "")
  }

  @Test
  func passkeyHooksAreInstalledOnClerkInstance() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyHookProbe(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          return {
            create: typeof clerk.__internal_createPublicCredentials,
            get: typeof clerk.__internal_getPublicCredentials,
            supportedType: typeof clerk.__internal_isWebAuthnSupported,
            supported: clerk.__internal_isWebAuthnSupported(),
            autofillType: typeof clerk.__internal_isWebAuthnAutofillSupported,
            autofill: await clerk.__internal_isWebAuthnAutofillSupported(),
            platformType: typeof clerk.__internal_isWebAuthnPlatformAuthenticatorSupported,
            platform: await clerk.__internal_isWebAuthnPlatformAuthenticatorSupported()
          };
        })()
        """
      )
    )
    #expect(payload.create == "function")
    #expect(payload.get == "function")
    #expect(payload.supportedType == "function")
    #expect(payload.supported)
    #expect(payload.autofillType == "function")
    #expect(!payload.autofill)
    #expect(payload.platformType == "function")
    #expect(payload.platform)
  }

  @Test
  func passkeyCreateRejectsMissingRpIdWithoutCeremony() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          try {
            await clerk.__internal_createPublicCredentials({});
            return { threw: false, message: '' };
          } catch (error) {
            return { threw: true, message: String(error.message || error) };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.message == "Invalid public key or RpID")
  }

  @Test
  func passkeyGetRejectsMissingOptionsWithoutCeremony() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          try {
            await clerk.__internal_getPublicCredentials({});
            return { threw: false, message: '' };
          } catch (error) {
            return { threw: true, message: String(error.message || error) };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.message == "publicKeyCredential has not been provided")
  }

  @Test
  func passkeyNativeBridgeRejectsInvalidCreatePayload() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodePasskeyCredentialReturn(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.passkeyHookInstallSource)
          var result = await clerk.__internal_createPublicCredentials({
            rp: { id: 'example.com' },
            user: { id: '', displayName: 'Ada' },
            challenge: new Uint8Array([1, 2, 3]).buffer
          });
          return {
            hasCredential: result.publicKeyCredential != null,
            errorCode: result.error && result.error.code,
            errorName: result.error && result.error.name
          };
        })()
        """
      )
    )
    #expect(!payload.hasCredential)
    #expect(payload.errorCode == "passkey_registration_failed")
    #expect(payload.errorName == "ClerkWebAuthnError")
  }

  @Test
  func loadHydratesClientFromResourceCacheOnNetworkError() async throws {
    let clientURL = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let environmentURL = try #require(Bundle.module.url(forResource: "environment", withExtension: "json"))
    let clientData = try Data(contentsOf: clientURL)
    let environmentData = try Data(contentsOf: environmentURL)
    let decoded = try FAPIJSON.decodeClient(clientData)
    #expect(decoded.id == "client_fixture")

    let cache = ClerkJSResourceCache.memory()
    await cache.save(ClerkJSCachedResources(client: clientData, environment: environmentData))

    let runtime = ClerkJSRuntime(resourceCache: cache)
    let stubbed = try await decodeJSONBool(
      runtime.evaluateJSON(
        """
        (function() {
          globalThis.__clerkFetchCalls = 0;
          globalThis.fetch = function() {
            globalThis.__clerkFetchCalls += 1;
            return Promise.reject(new Error('Failed to fetch'));
          };
          return true;
        })()
        """
      )
    )
    #expect(stubbed)

    try await runtime.load(publishableKey: mockPublishableKey)

    let clientId = try await decodeJSONString(
      runtime.evaluateJSON("globalThis.__clerkInstance.client.id")
    )
    #expect(clientId == "client_fixture")
    let fetchCalls = try await JSONDecoder().decode(
      Int.self,
      from: Data((runtime.evaluateJSON("globalThis.__clerkFetchCalls")).utf8)
    )
    #expect(fetchCalls > 0)
  }

  @Test
  @MainActor
  func loadPublishesCachedClientOnNetworkError() async throws {
    let clientURL = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let environmentURL = try #require(Bundle.module.url(forResource: "environment", withExtension: "json"))
    let clientData = try Data(contentsOf: clientURL)
    let environmentData = try Data(contentsOf: environmentURL)

    let cache = ClerkJSResourceCache.memory()
    await cache.save(ClerkJSCachedResources(client: clientData, environment: environmentData))

    let clerk = Clerk(
      publishableKey: mockPublishableKey,
      tokenCache: .memory(),
      resourceCache: cache
    )
    let stubbed = try await decodeJSONBool(
      clerk.runtime.evaluateJSON(
        """
        (function() {
          globalThis.fetch = function() {
            return Promise.reject(new Error('Failed to fetch'));
          };
          return true;
        })()
        """
      )
    )
    #expect(stubbed)

    try await clerk.load()
    #expect(clerk.client.id == "client_fixture")
    #expect(clerk.client.sessions.isEmpty)
  }

  @Test
  @MainActor
  func loadPublishesWatchCompanionFromCachedClientOnNetworkError() async throws {
    let clientURL = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let environmentURL = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    let clientData = try Data(contentsOf: clientURL)
    let environmentData = try Data(contentsOf: environmentURL)

    let cache = ClerkJSResourceCache.memory()
    await cache.save(ClerkJSCachedResources(client: clientData, environment: environmentData))

    let clerk = Clerk(
      publishableKey: mockPublishableKey,
      tokenCache: .memory(),
      resourceCache: cache
    )
    let stubbed = try await decodeJSONBool(
      clerk.runtime.evaluateJSON(
        """
        (function() {
          globalThis.fetch = function() {
            return Promise.reject(new Error('Failed to fetch'));
          };
          return true;
        })()
        """
      )
    )
    #expect(stubbed)

    try await clerk.load()
    var replica = WatchCompanion()
    try replica.apply(clerk.watchCompanion.encode())
    #expect(replica.client?.id == "client_fixture")
    #expect(replica.environment?.id == "env_fixture")
    #expect(clerk.nativeSettings == .default)
  }

  @Test
  @MainActor
  func loadPublishesNativeSettingsFromCachedEnvironment() async throws {
    let clientURL = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let environmentURL = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    let clientData = try Data(contentsOf: clientURL)
    var environment = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: environmentURL)) as? [String: Any]
    )
    var authConfig = try #require(environment["auth_config"] as? [String: Any])
    authConfig["native_settings"] = [
      "api_enabled": true,
      "trusted_device_sign_in_enabled": true,
      "trusted_device_enrollment_prompt_after_sign_in_enabled": true,
      "trusted_device_enrollment_prompt_after_sign_up_enabled": true,
    ]
    environment["auth_config"] = authConfig
    let environmentData = try JSONSerialization.data(withJSONObject: environment)

    let cache = ClerkJSResourceCache.memory()
    await cache.save(ClerkJSCachedResources(client: clientData, environment: environmentData))

    let clerk = Clerk(
      publishableKey: mockPublishableKey,
      tokenCache: .memory(),
      resourceCache: cache
    )
    let stubbed = try await decodeJSONBool(
      clerk.runtime.evaluateJSON(
        """
        (function() {
          globalThis.fetch = function() {
            return Promise.reject(new Error('Failed to fetch'));
          };
          return true;
        })()
        """
      )
    )
    #expect(stubbed)

    try await clerk.load()
    #expect(clerk.nativeSettings.apiEnabled)
    #expect(clerk.nativeSettings.biometricSignInEnabled)
    #expect(clerk.nativeSettings.biometricCredentialPromptAfterSignInEnabled)
    #expect(clerk.nativeSettings.biometricCredentialPromptAfterSignUpEnabled)
  }

  @Test
  @MainActor
  func loadPublishesEnvironmentFromCachedSnapshot() async throws {
    let clientURL = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let environmentURL = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    let clientData = try Data(contentsOf: clientURL)
    let environmentData = try Data(contentsOf: environmentURL)

    let cache = ClerkJSResourceCache.memory()
    await cache.save(ClerkJSCachedResources(client: clientData, environment: environmentData))

    let clerk = Clerk(
      publishableKey: mockPublishableKey,
      tokenCache: .memory(),
      resourceCache: cache
    )
    let stubbed = try await decodeJSONBool(
      clerk.runtime.evaluateJSON(
        """
        (function() {
          globalThis.fetch = function() {
            return Promise.reject(new Error('Failed to fetch'));
          };
          return true;
        })()
        """
      )
    )
    #expect(stubbed)

    try await clerk.load()
    #expect(clerk.environment?.id == "env_fixture")
    #expect(clerk.client.id == "client_fixture")
    let environment = try #require(clerk.environment)
    #expect(environment.emailIsEnabled)
    #expect(!environment.phoneNumberIsEnabled)
  }

  @Test
  func callReturningStringifiesObjectResults() async throws {
    let runtime = ClerkJSRuntime()
    _ = try await runtime.evaluateJSON(
      """
      (function() {
        globalThis.__returningProbe = {
          createTOTP: function() {
            return { id: 'totp_1', secret: 's3cret', uri: 'otpauth://totp/x' };
          }
        };
        return true;
      })()
      """
    )
    let json = try await runtime.callReturning(
      methodPath: "__returningProbe.createTOTP",
      args: EmptyCallArgs()
    )
    let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    #expect(object["id"] as? String == "totp_1")
    #expect(object["secret"] as? String == "s3cret")
    #expect(object["uri"] as? String == "otpauth://totp/x")
  }

  @Test
  func totpJSONForKitConvertsStringifiedResourceDates() throws {
    let input = Data(
      """
      {
        "id": "totp_1",
        "secret": "s3cret",
        "uri": "otpauth://totp/x",
        "verified": false,
        "backupCodes": ["a1"],
        "createdAt": "2023-11-14T22:13:20.000Z",
        "updatedAt": "2023-11-14T22:13:20.000Z",
        "pathRoot": "/me"
      }
      """.utf8
    )
    let data = ClerkJSUserJSON.totpForKit(input)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["id"] as? String == "totp_1")
    #expect(object["secret"] as? String == "s3cret")
    #expect((object["created_at"] as? NSNumber)?.doubleValue == 1_700_000_000_000)
    #expect((object["updated_at"] as? NSNumber)?.doubleValue == 1_700_000_000_000)
    #expect(object["backup_codes"] as? [String] == ["a1"])
    #expect(object["createdAt"] == nil)
    #expect(object["pathRoot"] == nil)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let totp = try decoder.decode(KitTOTPResource.self, from: data)
    #expect(totp.id == "totp_1")
    #expect(totp.secret == "s3cret")
    #expect(totp.verified == false)
    #expect(totp.createdAt.timeIntervalSince1970 == 1_700_000_000)
  }

  @Test
  func resourceCacheHostPersistsSnapshots() async throws {
    let cache = ClerkJSResourceCache.memory()
    let runtime = ClerkJSRuntime(resourceCache: cache)
    let payload = try await decodeCachedResources(
      runtime.evaluateJSON(
        """
        (async function() {
          await __clerkNativeSaveCachedResources(JSON.stringify({
            client: { object: 'client', id: 'client_saved' },
            environment: { object: 'environment', id: 'env_saved' }
          }));
          return await __clerkNativeGetCachedResources();
        })()
        """
      )
    )
    #expect(payload.client?.id == "client_saved")
    #expect(payload.environment?.id == "env_saved")
    let stored = await cache.load()
    #expect(stored.client != nil)
    #expect(stored.environment != nil)
  }
}

private struct KitTOTPResource: Decodable {
  var id: String
  var secret: String?
  var uri: String?
  var verified: Bool
  var backupCodes: [String]?
  var createdAt: Date
  var updatedAt: Date
}

private struct EmptyCallArgs: Encodable {}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}

private func decodeJSONBool(_ json: String) throws -> Bool {
  try JSONDecoder().decode(Bool.self, from: Data(json.utf8))
}

private struct CachedResourceJSON: Decodable {
  var object: String
  var id: String?
}

private struct CachedResourcesJSON: Decodable {
  var client: CachedResourceJSON?
  var environment: CachedResourceJSON?
}

private func decodeCachedResources(_ json: String) throws -> CachedResourcesJSON {
  try JSONDecoder().decode(CachedResourcesJSON.self, from: Data(json.utf8))
}

private struct PasskeyHookProbe: Decodable {
  var create: String
  var get: String
  var supportedType: String
  var supported: Bool
  var autofillType: String
  var autofill: Bool
  var platformType: String
  var platform: Bool
}

private struct PasskeyThrown: Decodable {
  var threw: Bool
  var message: String
}

private struct PasskeyCredentialReturn: Decodable {
  var hasCredential: Bool
  var errorCode: String?
  var errorName: String?
}

private func decodePasskeyHookProbe(_ json: String) throws -> PasskeyHookProbe {
  try JSONDecoder().decode(PasskeyHookProbe.self, from: Data(json.utf8))
}

private func decodePasskeyThrown(_ json: String) throws -> PasskeyThrown {
  try JSONDecoder().decode(PasskeyThrown.self, from: Data(json.utf8))
}

private func decodePasskeyCredentialReturn(_ json: String) throws -> PasskeyCredentialReturn {
  try JSONDecoder().decode(PasskeyCredentialReturn.self, from: Data(json.utf8))
}

private func applyScriptPayload(_ script: String) throws -> [String: Any] {
  let start = try #require(script.range(of: "JSON.parse(")?.upperBound)
  let rest = script[start...]
  let end = try #require(rest.range(of: "));")?.lowerBound)
  let jsonText = try JSONDecoder().decode(String.self, from: Data(String(rest[..<end]).utf8))
  return try #require(JSONSerialization.jsonObject(with: Data(jsonText.utf8)) as? [String: Any])
}
#endif
