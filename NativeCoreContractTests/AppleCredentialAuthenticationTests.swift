#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct AppleCredentialAuthenticationTests {
  private func binary(_ text: String) -> JSONValue {
    .object(["base64url": .string(text)])
  }

  private var assertion: [String: JSONValue] {
    ["rpId": .string("example.com"), "challenge": binary("BQYHCA"),
     "userVerification": .string("required"),
     "allowCredentials": .array([
       .object(["type": .string("public-key"), "id": binary("AQIDBA")]),
       .object(["type": .string("public-key"), "id": binary("aGVsbG8")]),
     ])]
  }

  @Test func assertionPreservesRelyingPartyChallengeAndCredentialRestrictions() async throws {
    let probe = CredentialProbe()
    let authentication = probe.authentication()
    let pending = Task { try await authentication.credential("passkeys.get", arguments: .object(assertion)) }
    let controller = await probe.controller(number: 1)
    let request = try #require(controller.authorizationRequests.first as? ASAuthorizationPlatformPublicKeyCredentialAssertionRequest)
    #expect(request.relyingPartyIdentifier == "example.com")
    #expect(request.challenge == Data([5, 6, 7, 8]))
    #expect(request.allowedCredentials.map(\.credentialID) == [Data([1, 2, 3, 4]), Data("hello".utf8)])
    #expect(request.userVerificationPreference == .required)
    controller.fail(.canceled)
    await expectFailure(pending, code: "user_cancelled")
  }

  @Test(arguments: [JSONValue.undefined, .object(["base64url": .string("")]), .object(["base64url": .string("!!!")])])
  func malformedCredentialRestrictionsFailBeforePresentation(invalidID: JSONValue) async throws {
    let probe = CredentialProbe()
    probe.rejectPresentedRequests = true
    var arguments = assertion
    arguments["allowCredentials"] = .array([.object(["id": invalidID]), .object(["id": binary("AQID")])])
    await #expect(throws: CoreError.self) {
      try await probe.authentication().credential("passkeys.get", arguments: .object(arguments))
    }
    #expect(probe.createdCount == 0)
  }

  @Test func registrationPreservesUserAndExcludedCredentials() async throws {
    #if !os(visionOS)
    guard #available(iOS 17.4, macOS 14.0, *) else { return }
    let probe = CredentialProbe()
    let authentication = probe.authentication()
    let arguments: JSONValue = .object([
      "challenge": binary("BQYHCA"),
      "rp": .object(["id": .string("example.com")]),
      "user": .object(["id": binary("AQID"), "name": .string("person@example.com"), "displayName": .string("Person")]),
      "pubKeyCredParams": .array([.object(["alg": .number(-7), "type": .string("public-key")])]),
      "authenticatorSelection": .object(["userVerification": .string("required")]),
      "excludeCredentials": .array([.object(["id": binary("aGVsbG8")])]),
    ])
    let pending = Task { try await authentication.credential("passkeys.create", arguments: arguments) }
    let controller = await probe.controller(number: 1)
    let request = try #require(controller.authorizationRequests.first as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest)
    #expect(request.relyingPartyIdentifier == "example.com")
    #expect(request.challenge == Data([5, 6, 7, 8]))
    #expect(request.userID == Data([1, 2, 3]))
    #expect(request.name == "person@example.com")
    #expect(request.displayName == "Person")
    #expect(request.userVerificationPreference == .required)
    #expect(request.excludedCredentials?.map(\.credentialID) == [Data("hello".utf8)])
    controller.fail(.canceled)
    await expectFailure(pending, code: "user_cancelled")
    #endif
  }

  @Test func cancelledControllerCannotCompleteTheNextRequest() async throws {
    let probe = CredentialProbe()
    let authentication = probe.authentication()
    let first = Task { try await authentication.credential("passkeys.get", arguments: .object(assertion)) }
    let obsolete = await probe.controller(number: 1)
    first.cancel()
    await #expect(throws: CancellationError.self) { try await first.value }
    #expect(obsolete.wasCancelled)
    let second = Task { try await authentication.credential("passkeys.get", arguments: .object(assertion)) }
    let current = await probe.controller(number: 2)
    obsolete.fail(.canceled)
    current.fail(.failed)
    await expectFailure(second, code: "passkey_failed")
  }

  @Test func appleIdentityAndPasskeysShareOneCredentialPresenter() async throws {
    let probe = CredentialProbe()
    let authentication = probe.authentication()
    let first = Task { try await authentication.appleIdentity("appleIdentity", arguments: .object(["fullName": .bool(true)])) }
    let controller = await probe.controller(number: 1)
    let request = try #require(controller.authorizationRequests.first as? ASAuthorizationAppleIDRequest)
    #expect(request.requestedScopes == [.email, .fullName])
    do {
      _ = try await authentication.credential("passkeys.get", arguments: .object(assertion))
      Issue.record("Expected an occupied presenter to reject another request")
    } catch let error as CoreError { #expect(error.code == "presentation_in_progress") }
    controller.fail(.failed)
    await expectFailure(first, code: "apple_identity_failed")
    #expect(probe.createdCount == 1)
  }

  private func expectFailure(_ task: Task<JSONValue, any Error>, code: String) async {
    do {
      _ = try await task.value
      Issue.record("Expected structured authorization failure")
    } catch let error as CoreError { #expect(error.code == code) }
    catch { Issue.record("Unexpected error: \(error)") }
  }
}

@MainActor
private final class CredentialProbe {
  var rejectPresentedRequests = false
  private var controllers: [StubAuthorizationController] = []
  private var waiter: CheckedContinuation<Void, Never>?
  private var requestedCount = 0
  var createdCount: Int {
    controllers.count
  }

  func authentication() -> AppleAuthentication {
    AppleAuthentication(anchor: { preconditionFailure("The stub must not present native UI") }, makeCredentialController: { requests in
      let controller = StubAuthorizationController(authorizationRequests: requests)
      self.controllers.append(controller)
      if self.rejectPresentedRequests {
        Task { @MainActor in controller.fail(.failed) }
      }
      if self.controllers.count == self.requestedCount, let waiter = self.waiter {
        self.waiter = nil
        waiter.resume()
      }
      return controller
    })
  }

  func controller(number: Int) async -> StubAuthorizationController {
    if controllers.count >= number { return controllers[number - 1] }
    requestedCount = number
    await withCheckedContinuation { waiter = $0 }
    return controllers[number - 1]
  }
}

private final class StubAuthorizationController: ASAuthorizationController {
  private(set) var wasCancelled = false
  override func performRequests() {}
  override func performRequests(options _: ASAuthorizationController.RequestOptions) {}
  #if os(iOS) && !targetEnvironment(macCatalyst)
  override func performAutoFillAssistedRequests() {}
  #endif
  override func cancel() {
    wasCancelled = true
  }

  @MainActor func fail(_ code: ASAuthorizationError.Code) {
    delegate?.authorizationController?(controller: self, didCompleteWithError: ASAuthorizationError(code))
  }
}
#endif
