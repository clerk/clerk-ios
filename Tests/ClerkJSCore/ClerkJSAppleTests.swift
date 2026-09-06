#if !os(watchOS)
import AuthenticationServices
@testable import ClerkJSCore
import Foundation
import Testing

private let mockPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

struct ClerkJSAppleTests {
  @Test
  func parseDefaultsNonceAndScopes() throws {
    let request = try ClerkJSAppleCeremony.parse("{}").get()
    #expect(!request.nonce.isEmpty)
    #expect(request.scopes == [.fullName, .email])
  }

  @Test
  func parseReadsNonceAndScopes() throws {
    let request = try ClerkJSAppleCeremony.parse(
      #"{"nonce":"abc-123","scopes":["email"]}"#
    ).get()
    #expect(request.nonce == "abc-123")
    #expect(request.scopes == [.email])
    #expect(request.authorizationScopes == [.email])
  }

  @Test
  func parseRejectsInvalidJSON() {
    let result = ClerkJSAppleCeremony.parse("not-json")
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "apple_invalid_payload")
  }

  @Test
  func parseRejectsUnknownScope() {
    let result = ClerkJSAppleCeremony.parse(#"{"scopes":["faceID"]}"#)
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "apple_invalid_payload")
  }

  @Test
  func parseRejectsNonStringNonce() {
    let result = ClerkJSAppleCeremony.parse(#"{"nonce":1}"#)
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "apple_invalid_payload")
  }

  @Test
  func validatedRejectsEmptyIdentityToken() {
    let result = ClerkJSAppleCeremony.validated(AppleIdentityToken(identityToken: "   "))
    guard case .failure(let error) = result else {
      Issue.record("Expected invalid payload")
      return
    }
    #expect(error.code == "apple_invalid_payload")
  }

  @Test
  func validatedTrimsNames() throws {
    let identity = try ClerkJSAppleCeremony.validated(
      AppleIdentityToken(identityToken: " token ", firstName: " Ada ", lastName: " ")
    ).get()
    #expect(identity.identityToken == "token")
    #expect(identity.firstName == "Ada")
    #expect(identity.lastName == nil)
  }

  @Test
  func mapsCanceledAuthorization() {
    let error = ClerkJSAppleError.from(ASAuthorizationError(.canceled))
    #expect(error.code == "apple_cancelled")
  }

  @Test
  func mapsCancellationError() {
    let error = ClerkJSAppleError.from(CancellationError())
    #expect(error.code == "apple_cancelled")
  }

  @Test
  func startReturnsIdentityFromPerformer() async throws {
    let ceremony = ClerkJSAppleCeremony()
    let probe = RequestProbe()
    ceremony.performer = { request in
      probe.request = request
      return AppleIdentityToken(identityToken: "id-token", firstName: "Ada", lastName: "Lovelace")
    }
    let identity = try await ceremony.start(payload: #"{"nonce":"n1","scopes":["email","fullName"]}"#).get()
    #expect(identity.identityToken == "id-token")
    #expect(identity.firstName == "Ada")
    #expect(identity.lastName == "Lovelace")
    #expect(probe.request?.nonce == "n1")
    #expect(probe.request?.scopes == [.email, .fullName])
  }

  @Test
  func startRejectsEmptyIdentityToken() async {
    let ceremony = ClerkJSAppleCeremony()
    ceremony.performer = { _ in
      AppleIdentityToken(identityToken: "")
    }
    let result = await ceremony.start(payload: "{}")
    guard case .failure(let error) = result else {
      Issue.record("Expected invalid payload")
      return
    }
    #expect(error.code == "apple_invalid_payload")
  }

  @Test
  func startMapsPerformerCancellation() async {
    let ceremony = ClerkJSAppleCeremony()
    ceremony.performer = { _ in
      throw CancellationError()
    }
    let result = await ceremony.start(payload: "{}")
    guard case .failure(let error) = result else {
      Issue.record("Expected cancel")
      return
    }
    #expect(error.code == "apple_cancelled")
  }

  @Test
  func startCancelInterruptsPerformer() async throws {
    let ceremony = ClerkJSAppleCeremony()
    let hang = HangProbe()
    ceremony.performer = { _ in
      try await withCheckedThrowingContinuation { continuation in
        hang.continuation = continuation
      }
    }
    async let started = ceremony.start(payload: "{}")
    for _ in 0 ..< 100 where hang.continuation == nil {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(hang.continuation != nil)
    ceremony.cancel()
    let result = await started
    guard case .failure(let error) = result else {
      Issue.record("Expected cancel")
      hang.continuation?.resume(throwing: CancellationError())
      return
    }
    #expect(error.code == "apple_cancelled")
    hang.continuation?.resume(throwing: CancellationError())
  }

  @Test
  func nativeBridgeIsInstalled() async throws {
    let runtime = ClerkJSRuntime()
    let kind = try await decodeJSONString(runtime.evaluateJSON("typeof __clerkNativeAppleSignIn"))
    #expect(kind == "function")
  }

  @Test
  func hookIsInstalledOnClerkInstance() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodeHookProbe(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appleHookInstallSource)
          return {
            hookType: typeof clerk.__internal_startAppleAuthentication,
            nativeType: typeof __clerkNativeAppleSignIn
          };
        })()
        """
      )
    )
    #expect(payload.hookType == "function")
    #expect(payload.nativeType == "function")
  }

  @Test
  func hookReturnsIdentityTokenPayload() async throws {
    let runtime = ClerkJSRuntime()
    runtime.appleCeremony.performer = { _ in
      AppleIdentityToken(identityToken: "id-token", firstName: "Ada", lastName: "Lovelace")
    }
    let payload = try await decodeIdentity(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appleHookInstallSource)
          return await clerk.__internal_startAppleAuthentication({ nonce: 'n1' });
        })()
        """
      )
    )
    #expect(payload.identityToken == "id-token")
    #expect(payload.firstName == "Ada")
    #expect(payload.lastName == "Lovelace")
  }

  @Test
  func hookRejectsCancellation() async throws {
    let runtime = ClerkJSRuntime()
    runtime.appleCeremony.performer = { _ in
      throw ASAuthorizationError(.canceled)
    }
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appleHookInstallSource)
          try {
            await clerk.__internal_startAppleAuthentication();
            return { threw: false, code: '', message: '' };
          } catch (error) {
            return {
              threw: true,
              code: error && error.code ? String(error.code) : '',
              message: String(error.message || error)
            };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.code == "apple_cancelled")
  }

  @Test
  func hookRejectsInvalidPayload() async throws {
    let runtime = ClerkJSRuntime()
    let payload = try await decodeThrown(
      runtime.evaluateJSON(
        """
        (async function() {
          var clerk = new Clerk('\(mockPublishableKey)');
          \(ClerkJSRuntime.appleHookInstallSource)
          try {
            await clerk.__internal_startAppleAuthentication({ scopes: ['faceID'] });
            return { threw: false, code: '', message: '' };
          } catch (error) {
            return {
              threw: true,
              code: error && error.code ? String(error.code) : '',
              message: String(error.message || error)
            };
          }
        })()
        """
      )
    )
    #expect(payload.threw)
    #expect(payload.code == "apple_invalid_payload")
  }

  @Test
  func clerkFacadeReturnsIdentity() async throws {
    let clerk = Clerk(publishableKey: mockPublishableKey)
    clerk.runtime.appleCeremony.performer = { _ in
      AppleIdentityToken(identityToken: "id-token", firstName: "Ada")
    }
    let identity = try await clerk.startAppleAuthentication()
    #expect(identity.identityToken == "id-token")
    #expect(identity.firstName == "Ada")
    #expect(identity.lastName == nil)
  }

  @Test
  func clerkFacadeMapsCancel() async {
    let clerk = Clerk(publishableKey: mockPublishableKey)
    clerk.runtime.appleCeremony.performer = { _ in
      throw ASAuthorizationError(.canceled)
    }
    do {
      _ = try await clerk.startAppleAuthentication()
      Issue.record("Expected cancel")
    } catch {
      #expect(error as? ClerkJSCoreError == .cancelled)
    }
  }
}

private final class RequestProbe: @unchecked Sendable {
  var request: ClerkJSAppleRequest?
}

private final class HangProbe: @unchecked Sendable {
  var continuation: CheckedContinuation<AppleIdentityToken, Error>?
}

private struct HookProbe: Decodable {
  var hookType: String
  var nativeType: String
}

private struct IdentityPayload: Decodable {
  var identityToken: String
  var firstName: String?
  var lastName: String?
}

private struct Thrown: Decodable {
  var threw: Bool
  var code: String
  var message: String
}

private func decodeHookProbe(_ json: String) throws -> HookProbe {
  try JSONDecoder().decode(HookProbe.self, from: Data(json.utf8))
}

private func decodeIdentity(_ json: String) throws -> IdentityPayload {
  try JSONDecoder().decode(IdentityPayload.self, from: Data(json.utf8))
}

private func decodeThrown(_ json: String) throws -> Thrown {
  try JSONDecoder().decode(Thrown.self, from: Data(json.utf8))
}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}
#endif
